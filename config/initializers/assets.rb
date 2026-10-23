# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Bootstrap 3.4.1 and jQuery live in vendor/ with their dist layout intact, so the
# Glyphicons ../fonts/ URLs in bootstrap.min.css resolve.
Rails.application.config.assets.paths << Rails.root.join("vendor")
