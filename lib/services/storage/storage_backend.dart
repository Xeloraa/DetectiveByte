import 'storage_backend_base.dart';

export 'storage_backend_base.dart';

import 'storage_backend_io.dart' if (dart.library.html) 'storage_backend_web.dart'
    as impl;

Future<StorageBackend> createStorageBackend() => impl.createStorageBackend();
