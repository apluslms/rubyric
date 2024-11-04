# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )

Rails.application.config.assets.precompile += %w(
	views/frontpage/show.js
	views/course_instances/new.js
	views/orders/index.js 
    views/orders/new.js
    views/reviews/edit.js 
    views/reviews/annotation.js
    views/rubrics/edit.js
	submissions.js
	editExercise.js
	assignmentEditor.js
	editInstructors.js
	reviewEditor.js
	rubricEditor.js 
	annotationEditor.js 
	price-calculator.js.coffee
	bootstrap.js
	frontpage.css
	application-new.css )
