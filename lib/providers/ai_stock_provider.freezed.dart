// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_stock_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AiStockState {
  List<Product> get products => throw _privateConstructorUsedError;
  bool get isLoadingProducts => throw _privateConstructorUsedError;
  bool get isGenerating => throw _privateConstructorUsedError;
  Product? get selectedProduct => throw _privateConstructorUsedError;
  String? get analysisPeriod => throw _privateConstructorUsedError;
  Map<String, dynamic>? get suggestion => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AiStockState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiStockStateCopyWith<AiStockState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiStockStateCopyWith<$Res> {
  factory $AiStockStateCopyWith(
          AiStockState value, $Res Function(AiStockState) then) =
      _$AiStockStateCopyWithImpl<$Res, AiStockState>;
  @useResult
  $Res call(
      {List<Product> products,
      bool isLoadingProducts,
      bool isGenerating,
      Product? selectedProduct,
      String? analysisPeriod,
      Map<String, dynamic>? suggestion,
      String? error});
}

/// @nodoc
class _$AiStockStateCopyWithImpl<$Res, $Val extends AiStockState>
    implements $AiStockStateCopyWith<$Res> {
  _$AiStockStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AiStockState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? products = null,
    Object? isLoadingProducts = null,
    Object? isGenerating = null,
    Object? selectedProduct = freezed,
    Object? analysisPeriod = freezed,
    Object? suggestion = freezed,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      products: null == products
          ? _value.products
          : products // ignore: cast_nullable_to_non_nullable
              as List<Product>,
      isLoadingProducts: null == isLoadingProducts
          ? _value.isLoadingProducts
          : isLoadingProducts // ignore: cast_nullable_to_non_nullable
              as bool,
      isGenerating: null == isGenerating
          ? _value.isGenerating
          : isGenerating // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedProduct: freezed == selectedProduct
          ? _value.selectedProduct
          : selectedProduct // ignore: cast_nullable_to_non_nullable
              as Product?,
      analysisPeriod: freezed == analysisPeriod
          ? _value.analysisPeriod
          : analysisPeriod // ignore: cast_nullable_to_non_nullable
              as String?,
      suggestion: freezed == suggestion
          ? _value.suggestion
          : suggestion // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AiStockStateImplCopyWith<$Res>
    implements $AiStockStateCopyWith<$Res> {
  factory _$$AiStockStateImplCopyWith(
          _$AiStockStateImpl value, $Res Function(_$AiStockStateImpl) then) =
      __$$AiStockStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<Product> products,
      bool isLoadingProducts,
      bool isGenerating,
      Product? selectedProduct,
      String? analysisPeriod,
      Map<String, dynamic>? suggestion,
      String? error});
}

/// @nodoc
class __$$AiStockStateImplCopyWithImpl<$Res>
    extends _$AiStockStateCopyWithImpl<$Res, _$AiStockStateImpl>
    implements _$$AiStockStateImplCopyWith<$Res> {
  __$$AiStockStateImplCopyWithImpl(
      _$AiStockStateImpl _value, $Res Function(_$AiStockStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiStockState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? products = null,
    Object? isLoadingProducts = null,
    Object? isGenerating = null,
    Object? selectedProduct = freezed,
    Object? analysisPeriod = freezed,
    Object? suggestion = freezed,
    Object? error = freezed,
  }) {
    return _then(_$AiStockStateImpl(
      products: null == products
          ? _value._products
          : products // ignore: cast_nullable_to_non_nullable
              as List<Product>,
      isLoadingProducts: null == isLoadingProducts
          ? _value.isLoadingProducts
          : isLoadingProducts // ignore: cast_nullable_to_non_nullable
              as bool,
      isGenerating: null == isGenerating
          ? _value.isGenerating
          : isGenerating // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedProduct: freezed == selectedProduct
          ? _value.selectedProduct
          : selectedProduct // ignore: cast_nullable_to_non_nullable
              as Product?,
      analysisPeriod: freezed == analysisPeriod
          ? _value.analysisPeriod
          : analysisPeriod // ignore: cast_nullable_to_non_nullable
              as String?,
      suggestion: freezed == suggestion
          ? _value._suggestion
          : suggestion // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$AiStockStateImpl implements _AiStockState {
  const _$AiStockStateImpl(
      {final List<Product> products = const [],
      this.isLoadingProducts = true,
      this.isGenerating = false,
      this.selectedProduct,
      this.analysisPeriod,
      final Map<String, dynamic>? suggestion,
      this.error})
      : _products = products,
        _suggestion = suggestion;

  final List<Product> _products;
  @override
  @JsonKey()
  List<Product> get products {
    if (_products is EqualUnmodifiableListView) return _products;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_products);
  }

  @override
  @JsonKey()
  final bool isLoadingProducts;
  @override
  @JsonKey()
  final bool isGenerating;
  @override
  final Product? selectedProduct;
  @override
  final String? analysisPeriod;
  final Map<String, dynamic>? _suggestion;
  @override
  Map<String, dynamic>? get suggestion {
    final value = _suggestion;
    if (value == null) return null;
    if (_suggestion is EqualUnmodifiableMapView) return _suggestion;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? error;

  @override
  String toString() {
    return 'AiStockState(products: $products, isLoadingProducts: $isLoadingProducts, isGenerating: $isGenerating, selectedProduct: $selectedProduct, analysisPeriod: $analysisPeriod, suggestion: $suggestion, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiStockStateImpl &&
            const DeepCollectionEquality().equals(other._products, _products) &&
            (identical(other.isLoadingProducts, isLoadingProducts) ||
                other.isLoadingProducts == isLoadingProducts) &&
            (identical(other.isGenerating, isGenerating) ||
                other.isGenerating == isGenerating) &&
            (identical(other.selectedProduct, selectedProduct) ||
                other.selectedProduct == selectedProduct) &&
            (identical(other.analysisPeriod, analysisPeriod) ||
                other.analysisPeriod == analysisPeriod) &&
            const DeepCollectionEquality()
                .equals(other._suggestion, _suggestion) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_products),
      isLoadingProducts,
      isGenerating,
      selectedProduct,
      analysisPeriod,
      const DeepCollectionEquality().hash(_suggestion),
      error);

  /// Create a copy of AiStockState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiStockStateImplCopyWith<_$AiStockStateImpl> get copyWith =>
      __$$AiStockStateImplCopyWithImpl<_$AiStockStateImpl>(this, _$identity);
}

abstract class _AiStockState implements AiStockState {
  const factory _AiStockState(
      {final List<Product> products,
      final bool isLoadingProducts,
      final bool isGenerating,
      final Product? selectedProduct,
      final String? analysisPeriod,
      final Map<String, dynamic>? suggestion,
      final String? error}) = _$AiStockStateImpl;

  @override
  List<Product> get products;
  @override
  bool get isLoadingProducts;
  @override
  bool get isGenerating;
  @override
  Product? get selectedProduct;
  @override
  String? get analysisPeriod;
  @override
  Map<String, dynamic>? get suggestion;
  @override
  String? get error;

  /// Create a copy of AiStockState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiStockStateImplCopyWith<_$AiStockStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
