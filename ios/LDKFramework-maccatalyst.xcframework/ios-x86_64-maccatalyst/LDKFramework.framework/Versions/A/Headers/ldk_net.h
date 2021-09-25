#include "lightning.h"
#include <sys/socket.h>
/**
 * Initializes socket handling and spawns a background thread to handle socket
 * events and pass them to the given LDKPeerManager.
 *
 * Returns NULL on error, otherwise an opaque pointer which should be passed as
 * `handler` in the remaining functions.
 */
void* init_socket_handling(const struct LDKPeerManager *NONNULL_PTR ldk_peer_manger);
/**
 * Stop the socket handling thread and free socket handling resources for the
 * given handler, as returned by init_socket_handling.
 */
void interrupt_socket_handling(void* handler);
/**
 * Bind the given address to accept incoming connections on the given handler's
 * background thread.
 * Returns 0 on success.
 */
int socket_bind(void* handler, struct sockaddr *addr, socklen_t addrlen);
/**
 * Connect to the given address and handle socket events on the given handler's
 * background thread.
 * Returns 0 on success.
 */
int socket_connect(void* handler, LDKPublicKey counterparty_pubkey, struct sockaddr *addr, size_t addrlen);
