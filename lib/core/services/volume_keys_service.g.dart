// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'volume_keys_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(volumeKeysService)
final volumeKeysServiceProvider = VolumeKeysServiceProvider._();

final class VolumeKeysServiceProvider
    extends
        $FunctionalProvider<
          VolumeKeysService,
          VolumeKeysService,
          VolumeKeysService
        >
    with $Provider<VolumeKeysService> {
  VolumeKeysServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'volumeKeysServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$volumeKeysServiceHash();

  @$internal
  @override
  $ProviderElement<VolumeKeysService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VolumeKeysService create(Ref ref) {
    return volumeKeysService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VolumeKeysService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VolumeKeysService>(value),
    );
  }
}

String _$volumeKeysServiceHash() => r'3d97de9e053799c41a43116fa0e6438f39c3cc5c';

@ProviderFor(volumeKeyEvents)
final volumeKeyEventsProvider = VolumeKeyEventsProvider._();

final class VolumeKeyEventsProvider
    extends
        $FunctionalProvider<AsyncValue<VolumeKey>, VolumeKey, Stream<VolumeKey>>
    with $FutureModifier<VolumeKey>, $StreamProvider<VolumeKey> {
  VolumeKeyEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'volumeKeyEventsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$volumeKeyEventsHash();

  @$internal
  @override
  $StreamProviderElement<VolumeKey> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<VolumeKey> create(Ref ref) {
    return volumeKeyEvents(ref);
  }
}

String _$volumeKeyEventsHash() => r'940e892baca384105ddf7880435f4f9e6348f747';
