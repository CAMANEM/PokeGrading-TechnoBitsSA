/// @file
/// @brief Configurable grading baseline per (set, finish) or global fallback.
///
/// Contains all thresholds used by the grading detectors. When no calibrated
/// baseline exists for a (set, finish) combination, the global fallback is used.
/// Each baseline is identified by a version string and recorded in the output.

/// Configurable thresholds for grading detectors.
///
/// All values are tuned to PSA/BGS industry standards.
/// Calibrated baselines override these values per (set, finish).
class BaselineConfig {
  /// Unique identifier for this baseline (e.g., "global_v1.0", "base_set_unlimited_holo_v1.2").
  final String version;

  /// Description of the baseline source.
  final String description;

  // --- Centering thresholds ---

  /// Minimum local color variance to consider a pixel as artwork (not border).
  final double artworkVarianceThreshold;

  /// Minimum percentage of pixels in a column/row that must show artwork variance.
  final double artworkConsensusThreshold;

  /// Maximum number of columns/rows to scan inward from the ROI edge.
  final int maxScanDepth;

  // --- Corner thresholds ---

  /// Brightness threshold for detecting exposed cardstock damage (0-255).
  /// White border is typically ~220-240; exposed cardstock is ~250-255.
  final double cornerWhiteningBrightnessThreshold;

  /// Saturation threshold for detecting white cardstock (0-255).
  final double cornerWhiteningSaturationThreshold;

  /// Fraction of the corner ROI tip to analyze (inner triangle).
  final double cornerTipFraction;

  /// Whitening percentage at or below which score is perfect.
  final double cornerWhiteningPerfectThreshold;

  /// Whitening percentage at or above which score is severe (BGS: >2% = detectable).
  final double cornerWhiteningFailThreshold;

  // --- Edge thresholds ---

  /// Brightness threshold for detecting exposed cardstock on edges (0-255).
  final double edgeWhiteningBrightnessThreshold;

  /// Saturation threshold for detecting white cardstock on edges (0-255).
  final double edgeWhiteningSaturationThreshold;

  /// Number of outer pixel rows/columns to analyze for whitening.
  final int outerEdgeRows;

  /// Edge whitening percentage at or below which score is perfect.
  final double edgeWhiteningPerfectThreshold;

  /// Edge whitening percentage at or above which score triggers a fail.
  final double edgeWhiteningFailThreshold;

  /// CV threshold for perfect edge straightness.
  final double straightnessCVPerfect;

  /// CV threshold for poor edge straightness.
  final double straightnessCVPoor;

  // --- Surface thresholds ---

  /// Sobel gradient magnitude threshold for scratch detection.
  final double scratchGradientThreshold;

  /// Maximum connected component size (in pixels) to classify as scratch.
  final int maxComponentSizeForScratch;

  /// Scratch density at or below which score is perfect (per 1000 pixels).
  final double perfectScratchDensity;

  /// Scratch density at or above which score is zero (per 1000 pixels).
  final double maxScratchDensity;

  /// CV threshold for print line detection.
  final double printLineCVThreshold;

  /// Block size (in pixels) for uniformity analysis.
  final int uniformityBlockSize;

  /// CV threshold for uniform surface (below = uniform).
  final double uniformCVThreshold;

  /// CV threshold for non-uniform surface (above = non-uniform).
  final double nonUniformCVThreshold;

  /// Creates a baseline configuration with all thresholds.
  const BaselineConfig({
    required this.version,
    required this.description,
    // Centering
    this.artworkVarianceThreshold = 300.0,
    this.artworkConsensusThreshold = 0.2,
    this.maxScanDepth = 150,
    // Corners
    this.cornerWhiteningBrightnessThreshold = 245.0,
    this.cornerWhiteningSaturationThreshold = 10.0,
    this.cornerTipFraction = 0.4,
    this.cornerWhiteningPerfectThreshold = 0.5,
    this.cornerWhiteningFailThreshold = 2.0,
    // Edges
    this.edgeWhiteningBrightnessThreshold = 245.0,
    this.edgeWhiteningSaturationThreshold = 10.0,
    this.outerEdgeRows = 3,
    this.edgeWhiteningPerfectThreshold = 0.5,
    this.edgeWhiteningFailThreshold = 3.0,
    this.straightnessCVPerfect = 0.10,
    this.straightnessCVPoor = 0.35,
    // Surface
    this.scratchGradientThreshold = 500.0,
    this.maxComponentSizeForScratch = 10,
    this.perfectScratchDensity = 0.01,
    this.maxScratchDensity = 0.5,
    this.printLineCVThreshold = 0.40,
    this.uniformityBlockSize = 60,
    this.uniformCVThreshold = 0.35,
    this.nonUniformCVThreshold = 1.0,
  });

  /// The global fallback baseline based on PSA/BGS industry standards.
  static const BaselineConfig globalFallback = BaselineConfig(
    version: 'global_v1.0',
    description: 'Baseline global basado en estandares PSA/BGS',
  );

  /// Converts this config to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'version': version,
    'description': description,
    'centering': {
      'artwork_variance_threshold': artworkVarianceThreshold,
      'artwork_consensus_threshold': artworkConsensusThreshold,
      'max_scan_depth': maxScanDepth,
    },
    'corners': {
      'whitening_brightness_threshold': cornerWhiteningBrightnessThreshold,
      'whitening_saturation_threshold': cornerWhiteningSaturationThreshold,
      'tip_fraction': cornerTipFraction,
      'whitening_perfect_threshold': cornerWhiteningPerfectThreshold,
      'whitening_fail_threshold': cornerWhiteningFailThreshold,
    },
    'edges': {
      'whitening_brightness_threshold': edgeWhiteningBrightnessThreshold,
      'whitening_saturation_threshold': edgeWhiteningSaturationThreshold,
      'outer_edge_rows': outerEdgeRows,
      'whitening_perfect_threshold': edgeWhiteningPerfectThreshold,
      'whitening_fail_threshold': edgeWhiteningFailThreshold,
      'straightness_cv_perfect': straightnessCVPerfect,
      'straightness_cv_poor': straightnessCVPoor,
    },
    'surface': {
      'scratch_gradient_threshold': scratchGradientThreshold,
      'max_component_size_for_scratch': maxComponentSizeForScratch,
      'perfect_scratch_density': perfectScratchDensity,
      'max_scratch_density': maxScratchDensity,
      'print_line_cv_threshold': printLineCVThreshold,
      'uniformity_block_size': uniformityBlockSize,
      'uniform_cv_threshold': uniformCVThreshold,
      'non_uniform_cv_threshold': nonUniformCVThreshold,
    },
  };

  /// Creates a BaselineConfig from a JSON map.
  factory BaselineConfig.fromJson(Map<String, dynamic> json) {
    final centering = json['centering'] as Map<String, dynamic>? ?? {};
    final corners = json['corners'] as Map<String, dynamic>? ?? {};
    final edges = json['edges'] as Map<String, dynamic>? ?? {};
    final surface = json['surface'] as Map<String, dynamic>? ?? {};

    return BaselineConfig(
      version: json['version'] as String? ?? 'unknown',
      description: json['description'] as String? ?? '',
      // Centering
      artworkVarianceThreshold: (centering['artwork_variance_threshold'] as num?)?.toDouble() ?? 300.0,
      artworkConsensusThreshold: (centering['artwork_consensus_threshold'] as num?)?.toDouble() ?? 0.2,
      maxScanDepth: (centering['max_scan_depth'] as num?)?.toInt() ?? 150,
      // Corners
      cornerWhiteningBrightnessThreshold: (corners['whitening_brightness_threshold'] as num?)?.toDouble() ?? 245.0,
      cornerWhiteningSaturationThreshold: (corners['whitening_saturation_threshold'] as num?)?.toDouble() ?? 10.0,
      cornerTipFraction: (corners['tip_fraction'] as num?)?.toDouble() ?? 0.4,
      cornerWhiteningPerfectThreshold: (corners['whitening_perfect_threshold'] as num?)?.toDouble() ?? 0.5,
      cornerWhiteningFailThreshold: (corners['whitening_fail_threshold'] as num?)?.toDouble() ?? 2.0,
      // Edges
      edgeWhiteningBrightnessThreshold: (edges['whitening_brightness_threshold'] as num?)?.toDouble() ?? 245.0,
      edgeWhiteningSaturationThreshold: (edges['whitening_saturation_threshold'] as num?)?.toDouble() ?? 10.0,
      outerEdgeRows: (edges['outer_edge_rows'] as num?)?.toInt() ?? 3,
      edgeWhiteningPerfectThreshold: (edges['whitening_perfect_threshold'] as num?)?.toDouble() ?? 0.5,
      edgeWhiteningFailThreshold: (edges['whitening_fail_threshold'] as num?)?.toDouble() ?? 3.0,
      straightnessCVPerfect: (edges['straightness_cv_perfect'] as num?)?.toDouble() ?? 0.10,
      straightnessCVPoor: (edges['straightness_cv_poor'] as num?)?.toDouble() ?? 0.35,
      // Surface
      scratchGradientThreshold: (surface['scratch_gradient_threshold'] as num?)?.toDouble() ?? 500.0,
      maxComponentSizeForScratch: (surface['max_component_size_for_scratch'] as num?)?.toInt() ?? 10,
      perfectScratchDensity: (surface['perfect_scratch_density'] as num?)?.toDouble() ?? 0.01,
      maxScratchDensity: (surface['max_scratch_density'] as num?)?.toDouble() ?? 0.5,
      printLineCVThreshold: (surface['print_line_cv_threshold'] as num?)?.toDouble() ?? 0.40,
      uniformityBlockSize: (surface['uniformity_block_size'] as num?)?.toInt() ?? 60,
      uniformCVThreshold: (surface['uniform_cv_threshold'] as num?)?.toDouble() ?? 0.35,
      nonUniformCVThreshold: (surface['non_uniform_cv_threshold'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
