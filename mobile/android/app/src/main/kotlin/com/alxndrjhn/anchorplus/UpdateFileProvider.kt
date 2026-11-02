package com.alxndrjhn.anchorplus

import androidx.core.content.FileProvider

/** Hands a downloaded update to Android's installer. Its own class, so it
 * doesn't clash with plugins' providers in the merged manifest. */
class UpdateFileProvider : FileProvider()
