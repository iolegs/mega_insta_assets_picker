import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_crop/image_crop.dart' hide CropState;
import 'package:insta_assets_picker/src/custom_packages/image_crop/crop.dart'
    show CropState, CropInternal;
import 'package:insta_assets_picker/insta_assets_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// Uses [InstaAssetsCropSingleton] to keep crop parameters in memory until the picker is disposed
/// Similar to [Singleton] class from `wechat_assets_picker` package
/// used only when [keepScrollOffset] is set to `true`
class InstaAssetsCropSingleton {
  const InstaAssetsCropSingleton._();

  static List<InstaAssetsCrop> cropParameters = [];
}

/// Contains all the parameters of the exportation
class InstaAssetsExportDetails {
  /// The list of the cropped files
  final List<File> croppedFiles;

  /// The selected thumbnails, can provided to the picker to preselect those assets
  final List<AssetEntity> selectedAssets;

  /// The selected [aspectRatio] (1 or 4/5)
  final double aspectRatio;

  /// The [progress] param represents progress indicator between `0.0` and `1.0`.
  final double progress;

  const InstaAssetsExportDetails({
    required this.croppedFiles,
    required this.selectedAssets,
    required this.aspectRatio,
    required this.progress,
  });
}

/// The crop parameters state, can be used at exportation or to load the crop view
class InstaAssetsCrop {
  final AssetEntity asset;
  final CropInternal? cropParam;

  // export crop params
  final double scale;
  final Rect? area;

  const InstaAssetsCrop({
    required this.asset,
    required this.cropParam,
    this.scale = 1.0,
    this.area,
  });

  static InstaAssetsCrop fromState({
    required AssetEntity asset,
    required CropState? cropState,
  }) {
    return InstaAssetsCrop(
      asset: asset,
      cropParam: cropState?.internalParameters,
      scale: cropState?.scale ?? 1.0,
      area: cropState?.area,
    );
  }
}

/// The controller that handles the exportation and save the state of the selected assets crop parameters
class InstaAssetsCropController {
  InstaAssetsCropController(this.keepMemory, bool isSquareDefaultCrop)
      : isSquare = ValueNotifier<bool>(isSquareDefaultCrop);

  /// Whether the crop view aspect ratio is 1 or 4/5
  late final ValueNotifier<bool> isSquare;

  /// Whether the image in the crop view is loaded
  final ValueNotifier<bool> isCropViewReady = ValueNotifier<bool>(false);

  /// The asset [AssetEntity] currently displayed in the crop view
  final ValueNotifier<AssetEntity?> previewAsset =
      ValueNotifier<AssetEntity?>(null);

  /// List of all the crop parameters set by the user
  List<InstaAssetsCrop> _cropParameters = [];

  /// Whether if [_cropParameters] should be saved in the cache to use when the picker
  /// is open with [InstaAssetPicker.restorableAssetsPicker]
  bool keepMemory = false;

  dispose() {
    clear();
    isCropViewReady.dispose();
    isSquare.dispose();
    previewAsset.dispose();
  }

  double get aspectRatio => isSquare.value ? 1 : 4 / 5;

  /// Use [_cropParameters] when [keepMemory] is `false`, otherwise use [InstaAssetsCropSingleton.cropParameters]
  List<InstaAssetsCrop> get cropParameters =>
      keepMemory ? InstaAssetsCropSingleton.cropParameters : _cropParameters;

  /// Save the list of crop parameters
  /// if [keepMemory] save list memory or simply in the controller
  void updateStoreCropParam(List<InstaAssetsCrop> list) {
    if (keepMemory) {
      InstaAssetsCropSingleton.cropParameters = list;
    } else {
      _cropParameters = list;
    }
  }

  /// Clear all the saved crop parameters
  void clear() {
    updateStoreCropParam([]);
    previewAsset.value = null;
  }

  /// When the preview asset is changed, save the crop parameters of the previous asset
  void onChange(
    AssetEntity? saveAsset,
    CropState? saveCropState,
    List<AssetEntity> selectedAssets,
  ) {
    final List<InstaAssetsCrop> newList = [];

    for (final asset in selectedAssets) {
      // get the already saved crop parameters if exists
      final savedCropAsset = get(asset);

      // if it is the asseet to save & the crop parameters exists
      if (asset == saveAsset && saveAsset != null) {
        // add the new parameters
        newList.add(InstaAssetsCrop.fromState(
          asset: saveAsset,
          cropState: saveCropState,
        ));
        // if it is not the asset to save and no crop parameter exists
      } else if (savedCropAsset == null) {
        // set empty crop parameters
        newList.add(InstaAssetsCrop.fromState(asset: asset, cropState: null));
      } else {
        // keep existing crop parameters
        newList.add(savedCropAsset);
      }
    }

    // overwrite the crop parameters list
    updateStoreCropParam(newList);
  }

  /// Returns the crop parametes [InstaAssetsCrop] of the given asset
  InstaAssetsCrop? get(AssetEntity asset) {
    if (cropParameters.isEmpty) return null;
    final index = cropParameters.indexWhere((e) => e.asset == asset);
    if (index == -1) return null;
    return cropParameters[index];
  }

  /// Apply all the crop parameters to the list of [selectedAssets]
  /// and returns the exportation as a [Stream]
  Stream<InstaAssetsExportDetails> exportCropFiles(
    List<AssetEntity> selectedAssets,
  ) async* {
    List<File> croppedFiles = [];

    /// Returns the [InstaAssetsExportDetails] with given progress value [p]
    InstaAssetsExportDetails makeDetail(double p) => InstaAssetsExportDetails(
          croppedFiles: croppedFiles,
          selectedAssets: selectedAssets,
          aspectRatio: aspectRatio,
          progress: p,
        );

    // start progress
    yield makeDetail(0);
    final list = cropParameters;

    final step = 1 / list.length;

    for (var i = 0; i < list.length; i++) {
      final asset = list[i].asset;
      final file = await asset.originFile;

      final scale = list[i].scale;
      final area = list[i].area;

      if (file == null) {
        throw 'error file is null';
      }

      if (asset.type == AssetType.video) {
        croppedFiles.add(file);
      } else {
        // makes the sample file to not be too small
        final sampledFile = await ImageCrop.sampleImage(
          file: file,
          preferredSize: (1024 / scale).round(),
        );

        if (area == null) {
          croppedFiles.add(sampledFile);
        } else {
          // crop the file with the area selected
          final croppedFile =
              await ImageCrop.cropImage(file: sampledFile, area: area);
          // delete the not needed sample file
          sampledFile.delete();

          croppedFiles.add(croppedFile);
        }
      }

      // increase progress
      yield makeDetail((i + 1) * step);
    }
    // complete progress
    yield makeDetail(1);
  }
}
