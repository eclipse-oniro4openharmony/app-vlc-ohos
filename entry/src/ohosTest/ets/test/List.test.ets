import abilityTest from './Ability.test';
import formatStoreTest from './FormatStore.test';
import settingsStoreTest from './SettingsStore.test';
import mediaStoreTest from './MediaStore.test';

export default function testsuite() {
  abilityTest();
  formatStoreTest();
  settingsStoreTest();
  mediaStoreTest();
}
