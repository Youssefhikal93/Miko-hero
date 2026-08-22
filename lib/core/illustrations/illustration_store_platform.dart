/// Single entry point that resolves the image cache of the current platform.
///
/// Windows, Android, iOS, macOS, and Linux keep page images as files under the
/// application support directory; web keeps them in IndexedDB. Every caller
/// imports this one library, so no feature has to know which build it is in.
library;

export 'illustration_store_web.dart'
    if (dart.library.io) 'illustration_store_io.dart'
    show createIllustrationStore;
