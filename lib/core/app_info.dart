/// The app's own version string, mirroring `pubspec.yaml`'s `version:`
/// field. Carried into an exported archive's envelope as `appVersion` —
/// informational only, never used for a compatibility decision (that's
/// `schemaVersion`, via `SchemaVersionPolicy`).
///
/// Hand-written rather than read through `package_info_plus`: that package
/// would be a whole new dependency bought for one display-only field, which
/// the data-transfer PRD's "no new dependency without justification"
/// constraint rules out here. Update this alongside `pubspec.yaml` when the
/// app's version changes.
const String kAppVersion = '1.0.0+1';
