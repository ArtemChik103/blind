// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(flutterTts)
final flutterTtsProvider = FlutterTtsProvider._();

final class FlutterTtsProvider
    extends $FunctionalProvider<FlutterTts, FlutterTts, FlutterTts>
    with $Provider<FlutterTts> {
  FlutterTtsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flutterTtsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flutterTtsHash();

  @$internal
  @override
  $ProviderElement<FlutterTts> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FlutterTts create(Ref ref) {
    return flutterTts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlutterTts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlutterTts>(value),
    );
  }
}

String _$flutterTtsHash() => r'5a5c264b933e2ea6dccf22d6bbac2f478adc6b79';

@ProviderFor(ttsService)
final ttsServiceProvider = TtsServiceProvider._();

final class TtsServiceProvider
    extends $FunctionalProvider<TtsService, TtsService, TtsService>
    with $Provider<TtsService> {
  TtsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsServiceHash();

  @$internal
  @override
  $ProviderElement<TtsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TtsService create(Ref ref) {
    return ttsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsService>(value),
    );
  }
}

String _$ttsServiceHash() => r'8fef6b112512c8c066171cf5a61b043d152bdb38';
