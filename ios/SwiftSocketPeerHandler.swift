//
//  SwiftSocketPeerHandler.swift
//  LDKSwiftARC
//
//  Created by Arik Sosman on 5/21/21.
//

import Foundation
import SwiftSocket

class SwiftSocketPeerHandler: ObservableObject {
    
    private let peerManager: PeerManager
    private let server: TCPServer
    private var ioWorkItem: DispatchWorkItem?
    private var eventProcessingItem: DispatchWorkItem?
    public private(set) var shutdown = false
    fileprivate var peersByConnectionId = [UInt64: TcpPeer]()
    @Published public fileprivate(set) var peers: [(UInt64, TCPClient)] = []
    
    private static var runningConnectionCounter: Int64 = 0
    
    init(peerManager: PeerManager) {
        self.peerManager = peerManager
        self.server = TCPServer(address: "127.0.0.1", port: 9735)
        
        self.ioWorkItem = DispatchWorkItem {
            if self.server.listen().isSuccess {
                while !self.shutdown {
                    if let client = self.server.accept() {
                        let peer = self.setupSocket(client: client)
                        DispatchQueue.main.async {
                            let inboundResult = self.peerManager.new_inbound_connection(descriptor: peer)
                            // self.peerManager.socket_disconnected(descriptor: peer)
                            if inboundResult.cOpaqueStruct?.result_ok == true {
                                self.peersByConnectionId[peer.connectionId] = peer
                                self.peers.append((peer.connectionId, client))
                                peer.doRead()
                            }
                        }
                    }
                }
            }
        }
        
        self.eventProcessingItem = DispatchWorkItem {
            var lastTimerTick = NSDate().timeIntervalSince1970
            while !self.shutdown {
                let currentTimerTick = NSDate().timeIntervalSince1970
                if lastTimerTick < (currentTimerTick-30) { // more than 30 seconds have passed since the last timer tick
                    print("calling PeerManager::timer_tick_occurred()")
                    self.peerManager.timer_tick_occurred()
                    lastTimerTick = currentTimerTick
                }
                print("calling PeerManager::process_events()")
                self.peerManager.process_events()
                Thread.sleep(forTimeInterval: 1)
            }
        }
        
        let backgroundQueueA = DispatchQueue(label: "org.ldk.SwiftSocketPeerHandler.ioThread", qos: .background)
        let backgroundQueueB = DispatchQueue(label: "org.ldk.SwiftSocketPeerHandler.eventProcessingThread", qos: .background)
        backgroundQueueA.async(execute: self.ioWorkItem!)
        backgroundQueueB.async(execute: self.eventProcessingItem!)
    }
    
    fileprivate func setupSocket(client: TCPClient) -> TcpPeer {
        OSAtomicIncrement64(&SwiftSocketPeerHandler.runningConnectionCounter)
        let socketDescriptor = TcpPeer(peerManager: self.peerManager, tcpClient: client, connectionId: SwiftSocketPeerHandler.runningConnectionCounter)
        return socketDescriptor
    }
    
    public func connect(address: String, port: Int32, theirNodeId: [UInt8]) -> UInt64? {
        if self.shutdown {
            return nil
        }
        let client = TCPClient(address: address, port: port)
        if client.connect(timeout: 5).isFailure {
            return nil
        }
        let peer = setupSocket(client: client)
        let outboundResult = self.peerManager.new_outbound_connection(their_node_id: theirNodeId, descriptor: peer)
        if outboundResult.cOpaqueStruct?.result_ok == true {
            self.peersByConnectionId[peer.connectionId] = peer
            self.peers.append((peer.connectionId, client))
            let firstMessage = outboundResult.cOpaqueStruct!.contents.result
            let firstMessageBytes = Bindings.LDKCVec_u8Z_to_array(nativeType: firstMessage!.pointee)
            peer.client.send(data: Data(firstMessageBytes))
            peer.doRead()
            return peer.connectionId
        }
        return nil
    }
    
    public func disconnect(connectionId: UInt64){
        if let peer = self.peersByConnectionId[connectionId] {
            peer.disconnect()
            self.objectWillChange.send()
        }
    }
    
    public func interrupt() {
        self.shutdown = true
        self.server.close()
        if let workItem = self.eventProcessingItem {
            workItem.wait()
            self.eventProcessingItem = nil
        }
        if let ioItem = self.ioWorkItem {
            ioItem.cancel()
            self.ioWorkItem = nil
        }
        self.objectWillChange.send()
        for (_, peer) in self.peersByConnectionId {
            peer.disconnect()
        }
        self.objectWillChange.send()
    }
    
}

fileprivate class TcpPeer: SocketDescriptor {
    /**
     * When we are told by LDK to disconnect, we can't return to LDK until we are sure
     * won't call any more read/write PeerManager functions with the same connection.
     * This is set to true if we're in such a condition (with disconnect checked
     * before with the Peer monitor lock held) and false when we can return.
     */
    var blockDisconnectSocket = false
    
    /**
     * Indicates LDK told us to disconnect this peer, and thus we should not call socket_disconnected.
     */
    var disconnectRequested = false
    
    /**
     * Indicates that the user requested disconnect this peer
     */
    var disconnectInitiated = false
    
    let peerManager: PeerManager
    let client: TCPClient
    let connectionId: UInt64
    
    let dispatchQueue: DispatchQueue
    var workItems: [DispatchWorkItem] = []
    
    init(peerManager: PeerManager, tcpClient: TCPClient, connectionId: Int64) {
        self.peerManager = peerManager
        self.client = tcpClient
        self.connectionId = UInt64(connectionId)
        self.dispatchQueue = DispatchQueue(label: "org.ldk.SwiftSocketPeerHandler.peerThread:\(self.connectionId)", qos: .background)
        super.init()
    }
    
    fileprivate func doRead() {
        if let bytesAvailable = self.client.bytesAvailable() {
            print("\(bytesAvailable) bytes available from peer #\(self.connectionId)")
            let workItem = DispatchWorkItem {
                if bytesAvailable == 0 {
                    Thread.sleep(forTimeInterval: 1)
                    self.doRead()
                    return
                }
                print("starting read from peer #\(self.connectionId)")
                if let readData = self.client.read(Int(bytesAvailable)){
                    let readBytes = [UInt8](readData)
                    print("Read from peer #\(self.connectionId):\n\(readBytes)\n")
                    
                    // after read, always write
                    self.peerManager.read_event(peer_descriptor: self, data: readBytes)
                }else{
                    print("read failed from peer #\(self.connectionId)")
                }
            }
            self.workItems.append(workItem)
            self.dispatchQueue.async(execute: workItem)
        }else {
            print("no bytes available from peer #\(self.connectionId)")
        }
    }
    
    override func send_data(data: [UInt8], resume_read: Bool) -> UInt {
        defer {
            // do the read at the end
            if resume_read {
                self.doRead()
            }
        }
        let result = self.client.send(data: Data(data))
        if result.isSuccess {
            print("Write to peer #\(self.connectionId):\n\(data)\n")
            return UInt(data.count)
        }
        return 0
    }
    
    fileprivate func disconnect() {
        if(!self.disconnectInitiated){
            self.disconnectInitiated = true
            self.peerManager.socket_disconnected(descriptor: self)
            self.client.close()
        }
    }
    
    override func disconnect_socket() {
        print("LDK disconnected from Peer #\(self.connectionId)")
        self.disconnectRequested = true
        self.client.close()
    }
    override func hash() -> UInt64 {
        return self.connectionId
    }
    override func eq(other_arg: SocketDescriptor) -> Bool {
        let comparable: TcpPeer = Bindings.pointerToInstance(pointer: other_arg.cOpaqueStruct!.this_arg)
        return comparable.connectionId == self.connectionId
    }
    
    override func clone() -> UnsafeMutableRawPointer {
        return self.cOpaqueStruct!.this_arg
        
        /*
        let clone = TcpPeer(peerManager: self.peerManager, tcpClient: self.client, connectionId: Int64(self.connectionId))
        clone.cOpaqueStruct!.this_arg = self.cOpaqueStruct!.this_arg // the Swift clone might disappear soon, only clone C struct
        let pointer = UnsafeMutablePointer<LDKSocketDescriptor>.allocate(capacity: 1)
        pointer.initialize(to: clone.cOpaqueStruct!)
        let rawPointer = UnsafeMutableRawPointer(pointer)
        return rawPointer
        */
    }

}
