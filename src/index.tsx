import { NativeModules } from 'react-native';

type RnLdkType = {
  multiply(a: number, b: number): Promise<number>;
};

const { RnLdk } = NativeModules;

export default RnLdk as RnLdkType;
