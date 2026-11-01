import * as path from 'path';
import { PUBLIC_PROFILES_PREFIX } from '../../config/storage.constants';

// Profile images are only ever saved as these types, with these extensions.
export const PROFILE_IMAGE_EXTENSIONS: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/gif': '.gif',
  'image/webp': '.webp',
};

/**
 * Where a stored profile image lives on disk, or null when the value is not
 * one of our own files (an external URL, or anything reaching outside the
 * profiles folder). Only a path this returns may be deleted.
 */
export function storedProfileImageFile(
  profilesDir: string,
  profileImage: string | null | undefined,
): string | null {
  const prefix = `${PUBLIC_PROFILES_PREFIX}/`;
  if (!profileImage?.startsWith(prefix)) return null;
  const filename = profileImage.slice(prefix.length);
  if (
    !filename ||
    filename === '.' ||
    filename === '..' ||
    filename.includes('/') ||
    filename.includes('\\')
  ) {
    return null;
  }
  return path.join(profilesDir, filename);
}
