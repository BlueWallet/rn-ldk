import AsyncStorage from '@react-native-async-storage/async-storage';

const defaultBaseUrl = 'https://bytes-store.herokuapp.com';

export default class SyncedAsyncStorage {
  namespace: string = '';

  constructor(namespace: string) {
    if (!namespace) throw new Error('namespace not provided');
    console.log({ namespace });
    this.namespace = namespace;
  }

  /**
   * @param key {string}
   * @param value {string}
   *
   * @return {string} New sequence number from remote
   */
  async setItemRemote(key: string, value: string): Promise<string> {
    const that = this;
    return new Promise(function (resolve, reject) {
      fetch(defaultBaseUrl + '/namespace/' + that.namespace + '/' + key, {
        method: 'POST',
        headers: {
          'Accept': 'text/plain',
          'Content-Type': 'text/plain',
        },
        body: value,
      })
        .then(async (response) => {
          console.log('seq num:');
          const text = await response.text();
          console.log(text);
          resolve(text);
        })
        .catch((reason) => reject(reason));
    });
  }

  async setItem(key: string, value: string) {
    await AsyncStorage.setItem(key, value);
    const newSeqNum = await this.setItemRemote(key, value);
    const localSeqNum = await this.getLocalSeqNum();
    if (+localSeqNum > +newSeqNum) {
      // some race condition during save happened..?
      return;
    }
    await AsyncStorage.setItem(this.namespace + '_' + 'seqnum', newSeqNum);
  }

  async getItemRemote(key: string) {
    const response = await fetch(defaultBaseUrl + '/namespace/' + this.namespace + '/' + key);
    return await response.text();
  }

  async getItem(key: string) {
    return AsyncStorage.getItem(key);
  }

  async getAllKeysRemote(): Promise<string[]> {
    const response = await fetch(defaultBaseUrl + '/namespacekeys/' + this.namespace);
    const text = await response.text();
    return text.split(',');
  }

  async getAllKeys(): Promise<string[]> {
    return AsyncStorage.getAllKeys();
  }

  async getLocalSeqNum() {
    return (await AsyncStorage.getItem(this.namespace + '_' + 'seqnum')) || '0';
  }

  /**
   * Should be called at init.
   * Checks remote sequence number, and if remote is ahead - we sync all keys with local storage.
   */
  async synchronize() {
    const response = await fetch(defaultBaseUrl + '/namespaceseq/' + this.namespace);
    const remoteSeqNum = (await response.text()) || '0';
    const localSeqNum = await this.getLocalSeqNum();
    if (+remoteSeqNum > +localSeqNum) {
      console.log('remote storage is ahead, need to sync;', +remoteSeqNum, '>', +localSeqNum);

      for (const key of await this.getAllKeysRemote()) {
        const value = await this.getItemRemote(key);
        await AsyncStorage.setItem(key, value);
        console.log('synced', key, 'to', value);
      }

      await AsyncStorage.setItem(this.namespace + '_' + 'seqnum', remoteSeqNum);
    } else {
      console.log('storage is up-to-date, no need for sync');
    }
  }
}
