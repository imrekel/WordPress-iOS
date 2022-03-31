# frozen_string_literal: true

#################################################
# Constants
#################################################

# URL of the GlotPress project which contains App strings
GLOTPRESS_APP_STRINGS_URL = 'https://translate.wordpress.org/projects/apps/ios/dev/'

# URL of the GlotPress projects containing AppStore metadata (title, keywords, release notes, …)
GLOTPRESS_WORDPRESS_METADATA_PROJECT_URL = 'https://translate.wordpress.org/projects/apps/ios/release-notes/'
GLOTPRESS_JETPACK_METADATA_PROJECT_URL = 'https://translate.wordpress.com/projects/jetpack/apps/ios/release-notes/'

# List of locales used for the app strings
# TODO: Replace with `LocaleHelper` once provided by release toolkit (https://github.com/wordpress-mobile/release-toolkit/pull/296)
#
GLOTPRESS_TO_LPROJ_APP_LOCALE_CODES = {
  'ar' => 'ar',         # Arabic
  'bg' => 'bg',         # Bulgarian
  'cs' => 'cs',         # Czech
  'cy' => 'cy',         # Welsh
  'da' => 'da',         # Danish
  'de' => 'de',         # German
  'en-au' => 'en-AU',   # English (Australia)
  'en-ca' => 'en-CA',   # English (Canada)
  'en-gb' => 'en-GB',   # English (UK)
  'es' => 'es',         # Spanish
  'fr' => 'fr',         # French
  'he' => 'he',         # Hebrew
  'hr' => 'hr',         # Croatian
  'hu' => 'hu',         # Hungarian
  'id' => 'id',         # Indonesian
  'is' => 'is',         # Icelandic
  'it' => 'it',         # Italian
  'ja' => 'ja',         # Japanese
  'ko' => 'ko',         # Korean
  'nb' => 'nb',         # Norwegian (Bokmål)
  'nl' => 'nl',         # Dutch
  'pl' => 'pl',         # Polish
  'pt' => 'pt',         # Portuguese
  'pt-br' => 'pt-BR',   # Portuguese (Brazil)
  'ro' => 'ro',         # Romainian
  'ru' => 'ru',         # Russian
  'sk' => 'sk',         # Slovak
  'sq' => 'sq',         # Albanian
  'sv' => 'sv',         # Swedish
  'th' => 'th',         # Thai
  'tr' => 'tr',         # Turkish
  'zh-cn' => 'zh-Hans', # Chinese (China)
  'zh-tw' => 'zh-Hant'  # Chinese (Taiwan)
}.freeze

# List of `.strings` files manually maintained by developers (as opposed to being automatically extracted from code and generated)
# which we will merge into the main `Localizable.strings` file imported by GlotPress, then extract back once we download the translations.
# Each `.strings` file to be merged/extracted is associated with a prefix to add the the keys being used to avoid conflicts and differentiate.
# See calls to `ios_merge_strings_files` and `ios_extract_keys_from_strings_files` for usage.
#
MANUALLY_MAINTAINED_STRINGS_FILES = {
  File.join('WordPress', 'Resources', 'en.lproj', 'InfoPlist.strings') => 'infoplist.', # For now WordPress and Jetpack share the same InfoPlist.strings
  File.join('WordPress', 'WordPressDraftActionExtension', 'en.lproj', 'InfoPlist.strings') => 'ios-sharesheet.', # CFBundleDisplayName for the "Save as Draft" share action
  File.join('WordPress', 'WordPressIntents', 'en.lproj', 'Sites.strings') => 'ios-widget.' # Strings from the `.intentdefinition`, used for configuring the iOS Widget
}.freeze

# Application-agnostic settings for the `upload_to_app_store` action (also known as `deliver`).
# Used in `update_*_metadata_on_app_store_connect` lanes.
#
UPLOAD_TO_APP_STORE_COMMON_PARAMS = {
  app_version: read_version_from_config,
  skip_binary_upload: true,
  overwrite_screenshots: true,
  phased_release: true,
  precheck_include_in_app_purchases: false,
  api_key_path: APP_STORE_CONNECT_KEY_PATH,
  app_rating_config_path: File.join(PROJECT_ROOT_FOLDER, 'fastlane', 'metadata', 'ratings_config.json')
}.freeze



#################################################
# Lanes
#################################################

# Lanes related to Localization and GlotPress
#
platform :ios do
  # Generates the `.strings` file to be imported by GlotPress, by parsing source code (using `genstrings` under the hood).
  #
  # @called_by complete_code_freeze
  #
  lane :generate_strings_file_for_glotpress do
    cocoapods

    wordpress_en_lproj = File.join('WordPress', 'Resources', 'en.lproj')
    ios_generate_strings_file_from_code(
      paths: ['WordPress/', 'Pods/WordPress*/', 'Pods/WPMediaPicker/', 'WordPressShared/WordPressShared/', 'Pods/Gutenberg/'],
      exclude: ['*Vendor*', 'WordPress/WordPressTest/**', '**/AppLocalizedString.swift'],
      routines: ['AppLocalizedString'],
      output_dir: wordpress_en_lproj
    )

    # Merge various manually-maintained `.strings` files into the previously generated `Localizable.strings` so their extra keys are also imported in GlotPress.
    # Note: We will re-extract the translations back during `download_localized_strings_and_metadata` (via a call to `ios_extract_keys_from_strings_files`)
    ios_merge_strings_files(
      paths_to_merge: MANUALLY_MAINTAINED_STRINGS_FILES,
      destination: File.join(wordpress_en_lproj, 'Localizable.strings')
    )

    git_commit(path: [wordpress_en_lproj], message: 'Update strings for localization', allow_nothing_to_commit: true)
  end



  # Updates the `AppStoreStrings.po` files (WP+JP) with the latest content from the `release_notes.txt` files and the other text sources
  #
  # @option [String] version The current `x.y` version of the app. Used to derive the `release_notes_xxy` key to use in the `.po` file.
  #
  desc 'Updates the AppStoreStrings.po file with the latest data'
  lane :update_appstore_strings do |options|
    update_wordpress_appstore_strings(options)
    update_jetpack_appstore_strings(options)
  end

  # Updates the `AppStoreStrings.po` file for WordPress, with the latest content from the `release_notes.txt` file and the other text sources
  #
  # @option [String] version The current `x.y` version of the app. Used to derive the `release_notes_xxy` key to use in the `.po` file.
  #
  desc 'Updates the AppStoreStrings.po file for the WordPress app with the latest data'
  lane :update_wordpress_appstore_strings do |options|
    source_metadata_folder = File.join(PROJECT_ROOT_FOLDER, 'fastlane', 'appstoreres', 'metadata', 'source')

    files = {
      whats_new: File.join(PROJECT_ROOT_FOLDER, 'WordPress', 'Resources', 'release_notes.txt'),
      app_store_name: File.join(source_metadata_folder, 'name.txt'),
      app_store_subtitle: File.join(source_metadata_folder, 'subtitle.txt'),
      app_store_desc: File.join(source_metadata_folder, 'description.txt'),
      app_store_keywords: File.join(source_metadata_folder, 'keywords.txt'),
      'standard-whats-new-1' => File.join(source_metadata_folder, 'standard_whats_new_1.txt'),
      'standard-whats-new-2' => File.join(source_metadata_folder, 'standard_whats_new_2.txt'),
      'standard-whats-new-3' => File.join(source_metadata_folder, 'standard_whats_new_3.txt'),
      'standard-whats-new-4' => File.join(source_metadata_folder, 'standard_whats_new_4.txt'),
      'app_store_screenshot-1' => File.join(source_metadata_folder, 'promo_screenshot_1.txt'),
      'app_store_screenshot-2' => File.join(source_metadata_folder, 'promo_screenshot_2.txt'),
      'app_store_screenshot-3' => File.join(source_metadata_folder, 'promo_screenshot_3.txt'),
      'app_store_screenshot-4' => File.join(source_metadata_folder, 'promo_screenshot_4.txt'),
      'app_store_screenshot-5' => File.join(source_metadata_folder, 'promo_screenshot_5.txt'),
      'app_store_screenshot-6' => File.join(source_metadata_folder, 'promo_screenshot_6.txt'),
      'app_store_screenshot-7' => File.join(source_metadata_folder, 'promo_screenshot_7.txt')
    }

    ios_update_metadata_source(
      po_file_path: File.join(PROJECT_ROOT_FOLDER, 'WordPress', 'Resources', 'AppStoreStrings.po'),
      source_files: files,
      release_version: options[:version]
    )
  end

  # Updates the `AppStoreStrings.po` file for Jetpack, with the latest content from the `release_notes.txt` file and the other text sources
  #
  # @option [String] version The current `x.y` version of the app. Used to derive the `release_notes_xxy` key to use in the `.po` file.
  #
  desc 'Updates the AppStoreStrings.po file for the Jetpack app with the latest data'
  lane :update_jetpack_appstore_strings do |options|
    source_metadata_folder = File.join(PROJECT_ROOT_FOLDER, 'fastlane', 'appstoreres', 'jetpack_metadata', 'source')

    files = {
      whats_new: File.join(PROJECT_ROOT_FOLDER, 'WordPress', 'Jetpack', 'Resources', 'release_notes.txt'),
      app_store_subtitle: File.join(source_metadata_folder, 'subtitle.txt'),
      app_store_desc: File.join(source_metadata_folder, 'description.txt'),
      app_store_keywords: File.join(source_metadata_folder, 'keywords.txt'),
      'screenshot-text-1' => File.join(source_metadata_folder, 'promo_screenshot_1.txt'),
      'screenshot-text-2' => File.join(source_metadata_folder, 'promo_screenshot_2.txt'),
      'screenshot-text-3' => File.join(source_metadata_folder, 'promo_screenshot_3.txt'),
      'screenshot-text-4' => File.join(source_metadata_folder, 'promo_screenshot_4.txt'),
      'screenshot-text-5' => File.join(source_metadata_folder, 'promo_screenshot_5.txt'),
      'screenshot-text-6' => File.join(source_metadata_folder, 'promo_screenshot_6.txt'),
      app_store_name: File.join(source_metadata_folder, 'name.txt')
    }

    ios_update_metadata_source(
      po_file_path: File.join(PROJECT_ROOT_FOLDER, 'WordPress', 'Jetpack', 'Resources', 'AppStoreStrings.po'),
      source_files: files,
      release_version: options[:version]
    )
  end


  # Downloads the localized app strings and App Store Connect metadata from GlotPress.
  #
  desc 'Downloads localized metadata for App Store Connect from GlotPress'
  lane :download_localized_strings_and_metadata do
    # Download `Localizable.strings` translations used within the app
    parent_dir_for_lprojs = File.join(PROJECT_ROOT_FOLDER, 'WordPress', 'Resources')
    ios_download_strings_files_from_glotpress(
      project_url: GLOTPRESS_APP_STRINGS_URL,
      locales: GLOTPRESS_TO_LPROJ_APP_LOCALE_CODES,
      download_dir: parent_dir_for_lprojs
    )
    git_commit(
      path: File.join(parent_dir_for_lprojs, '*.lproj', 'Localizable.strings'),
      message: 'Update app translations – `Localizable.strings`',
      allow_nothing_to_commit: true
    )

    # Redispatch the appropriate subset of translations back to the manually-maintained `.strings`
    # files that we previously merged via `ios_merge_strings_files` during `complete_code_freeze`
    modified_files = ios_extract_keys_from_strings_files(
      source_parent_dir: parent_dir_for_lprojs,
      target_original_files: MANUALLY_MAINTAINED_STRINGS_FILES
    )
    git_commit(
      path: modified_files,
      message: 'Update app translations – Other `.strings`',
      allow_nothing_to_commit: true
    )

    # Finally, also download the AppStore metadata (app title, keywords, etc.)
    # @FIXME: Replace this whole lane with a call to the future replacement of `gp_downloadmetadata` once it's implemented in the release-toolkit (see paaHJt-31O-p2).
    download_wordpress_localized_app_store_metadata
    download_jetpack_localized_app_store_metadata
  end

  # Downloads the localized metadata (for App Store Connect) from GlotPress for the WordPress app.
  #
  desc 'Downloads the localized metadata (for App Store Connect) from GlotPress for the WordPress app'
  lane :download_wordpress_localized_app_store_metadata do
    # @FIXME: Replace this whole lane with a call to the future replacement of `gp_downloadmetadata` once it's implemented in the release-toolkit (see paaHJt-31O-p2).

    # No need to `cd` into `fastlane` because of how Fastlane manages its paths internally.
    sh './download_metadata.swift wordpress'

    # @TODO: Make the `fastlane/metadata/en-US/release_notes.txt` path be the source of truth for the original copies in the future.
    # (will require changes in the `update_appstore_strings` lane, the Release Scenario, the MC tool to generate the announcement post…)
    #
    # In the meantime, since GlotPress doesn't have the `en-US` notes because those are the ones used as originals, just copy the file to the right place for `deliver` to find
    metadata_directory = File.join(PROJECT_ROOT_FOLDER, 'fastlane', 'metadata')
    release_notes_source = File.join(PROJECT_ROOT_FOLDER, 'WordPress', 'Resources', 'release_notes.txt')
    FileUtils.cp(release_notes_source, File.join(metadata_directory, 'en-US', 'release_notes.txt'))

    metadata_path = File.join(metadata_directory, '**', '*.txt')
    git_commit(
      path: metadata_path,
      message: 'Update WordPress metadata translations',
      allow_nothing_to_commit: true
    )
  end

  # Downloads the localized metadata (for App Store Connect) from GlotPress for the Jetpack app
  #
  desc 'Downloads the localized metadata (for App Store Connect) from GlotPress for the Jetpack app'
  lane :download_jetpack_localized_app_store_metadata do
    # @FIXME: Replace this whole lane with a call to the future replacement of `gp_downloadmetadata` once it's implemented in the release-toolkit (see paaHJt-31O-p2).

    # No need to `cd` into `fastlane` because of how Fastlane manages its paths internally.
    sh './download_metadata.swift jetpack'

    # @TODO: Make the `fastlane/jetpack_metadata/en-US/release_notes.txt` path be the source of truth for the original copies in the future.
    # (will require changes in the `update_appstore_strings` lane, the Release Scenario, the MC tool to generate the announcement post…)
    #
    # In the meantime, since GlotPress doesn't have the `en-US` notes because those are the ones used as originals, just copy the file to the right place for `deliver` to find
    metadata_directory = File.join(PROJECT_ROOT_FOLDER, 'fastlane', 'jetpack_metadata')
    release_notes_source = File.join(PROJECT_ROOT_FOLDER, 'WordPress', 'Jetpack', 'Resources', 'release_notes.txt')
    FileUtils.cp(release_notes_source, File.join(metadata_directory, 'en-US', 'release_notes.txt'))

    metadata_path = File.join(metadata_directory, '**', '*.txt')
    git_commit(
      path: metadata_path,
      message: 'Update Jetpack metadata translations',
      allow_nothing_to_commit: true
    )
  end



  # Uploads the localized metadata for WordPress and Jetpack (from `fastlane/{metadata,jetpack_metadata}/`) to App Store Connect
  #
  # @option [Boolean] with_screenshots (default: false) If true, will also upload the latest screenshot files to ASC
  #
  desc 'Updates the App Store Connect localized metadata'
  lane :update_metadata_on_app_store_connect do |options|
    update_wordpress_metadata_on_app_store_connect(options)
    update_jetpack_metadata_on_app_store_connect(options)
  end

  # Uploads the localized metadata for WordPress (from `fastlane/metadata/`) to App Store Connect
  #
  # @option [Boolean] with_screenshots (default: false) If true, will also upload the latest screenshot files to ASC
  #
  desc 'Uploads the WordPress metadata to App Store Connect, localized, and optionally including screenshots.'
  lane :update_wordpress_metadata_on_app_store_connect do |options|
    # Skip screenshots by default. The naming is "with" to make it clear that
    # callers need to opt-in to adding screenshots. The naming of the deliver
    # parameter, on the other hand, uses the skip verb.
    with_screenshots = options.fetch(:with_screenshots, false)
    skip_screenshots = with_screenshots == false

    upload_to_app_store(
      **UPLOAD_TO_APP_STORE_COMMON_PARAMS,
      app_identifier: APP_STORE_VERSION_BUNDLE_IDENTIFIER,
      screenshots_path: File.join(PROJECT_ROOT_FOLDER, 'fastlane', 'promo-screenshots'),
      skip_screenshots: skip_screenshots
    )
  end

  # Uploads the localized metadata for Jetpack (from `fastlane/jetpack_metadata/`) to App Store Connect
  #
  # @option [Boolean] with_screenshots (default: false) If true, will also upload the latest screenshot files to ASC
  #
  desc 'Uploads the Jetpack metadata to App Store Connect, localized, and optionally including screenshots.'
  lane :update_jetpack_metadata_on_app_store_connect do |options|
    # Skip screenshots by default. The naming is "with" to make it clear that
    # callers need to opt-in to adding screenshots. The naming of the deliver
    # parameter, on the other hand, uses the skip verb.
    with_screenshots = options.fetch(:with_screenshots, false)
    skip_screenshots = with_screenshots == false

    upload_to_app_store(
      **UPLOAD_TO_APP_STORE_COMMON_PARAMS,
      app_identifier: JETPACK_APP_IDENTIFIER,
      metadata_path: File.join(PROJECT_ROOT_FOLDER, 'fastlane', 'jetpack_metadata'),
      screenshots_path: File.join(PROJECT_ROOT_FOLDER, 'fastlane', 'jetpack_promo_screenshots'),
      skip_screenshots: skip_screenshots
    )
  end


  # Checks the translation progress (%) of all Mag16 for all the projects (app strings and metadata) in GlotPress.
  #
  # @option [Boolean] interactive (default: false) If true, will pause and ask confirmation to continue if it found any locale translated below the threshold
  #
  desc 'Check translation progress for all GlotPress projects'
  lane :check_all_translations do |options|
    abort_on_violations = false
    skip_confirm = options.fetch(:interactive, false) == false

    UI.message('Checking app strings translation status...')
    check_translation_progress(
      glotpress_url: GLOTPRESS_APP_STRINGS_URL,
      abort_on_violations: abort_on_violations,
      skip_confirm: skip_confirm
    )

    UI.message('Checking WordPress release notes strings translation status...')
    check_translation_progress(
      glotpress_url: GLOTPRESS_WORDPRESS_METADATA_PROJECT_URL,
      abort_on_violations: abort_on_violations,
      skip_confirm: skip_confirm
    )

    UI.message('Checking Jetpack release notes strings translation status...')
    check_translation_progress(
      glotpress_url: GLOTPRESS_JETPACK_METADATA_PROJECT_URL,
      abort_on_violations: abort_on_violations,
      skip_confirm: skip_confirm
    )
  end
end
