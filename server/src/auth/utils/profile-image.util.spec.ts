import { describe, expect, it } from 'vitest';
import * as path from 'path';
import { storedProfileImageFile } from './profile-image.util';

describe('storedProfileImageFile', () => {
  const dir = path.join('/data', 'uploads', 'profiles');

  it('finds one of our own files', () => {
    expect(storedProfileImageFile(dir, '/uploads/profiles/u-1.png')).toBe(
      path.join(dir, 'u-1.png'),
    );
  });

  it.each([
    [null],
    [''],
    ['https://idp.example.com/avatar.png'],
    // A picture claim stored as is used to reach outside the folder.
    ['https://x.invalid/../../../../app/server/dist/src/main.js'],
    ['/uploads/profiles/../../secret'],
    ['/uploads/profiles/..'],
    ['/uploads/profiles/a\\..\\..\\b'],
    ['/uploads/profiles/'],
    ['/uploads/profilesX/u-1.png'],
  ])('refuses %s', (value) => {
    expect(storedProfileImageFile(dir, value)).toBeNull();
  });
});
