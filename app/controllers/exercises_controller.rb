require 'set.rb'

class ExercisesController < ApplicationController
  before_action :login_required, except: [:lti, :aplus_exercise]

  def lti
    # Temporarily disable signature checking
    if params['lis_person_contact_email_primary'] == 'tapio.auvinen@aalto.fi' && !authenticate_lti_signature
      logger.info 'Failed to auth LTI signature'
      return
    end

    unless login_lti_user
      logger.info 'Failed to login LTI user'
      return
    end

    unless @exercise
      render template: 'shared/lti_error'
      return
    end

    redirect_to @exercise
  end

  # GET /exercises/1
  def show
    @exercise = Exercise.find(params[:id])
    load_course
    @course_instance_exercise_count = @course_instance.exercises.size
    I18n.locale = @course_instance.locale || I18n.locale

    if @course.has_teacher(current_user) || is_admin?(current_user)
      # Teacher's view
      @groups = @exercise.groups_with_submissions.order('groups.id, submissions.created_at DESC, reviews.id')
      
      # Count how many reviews everyone has done
      @finished = []
      @mailed = []
      @started = []
      @not_started =[]
      @graders = []
      # List graders (= teachers, assistants and all users who have done a review to submission on the exercise)
      grader_ids = Review.where(submission_id: @exercise.submissions).map { |r| r.user_id } + @course.teacher_ids + @course_instance.assistant_ids
      graders = User.where(id: grader_ids)
      
      i = 0
      graders.each do |g|
        all_reviews = g.reviews.where(submission_id: @exercise.submissions)
        assigned_submissions = g.assigned_groups.where(id: @groups.ids).map{ |group| group.submissions.where(id: @exercise.submissions).ids}.flatten
        f = 0; m = 0; s = 0; n = assigned_submissions.size
        all_reviews.each do |review|
          f = f + 1 if ["finished", "mailing"].include?(review.status)
          m = m + 1 if review.status == "mailed"
          s = s + 1 if review.status == "started" || review.status.blank?
          if review.status != "invalidated" && assigned_submissions.include?(review.submission.id)
            n = n - 1
            assigned_submissions -= [review.submission.id]
          end
        end
        all_review_group_ids = all_reviews.map{|review| review.submission.group.id}
        grader_groups = @groups.select{|group| all_review_group_ids.include?(group.id) || group.reviewer_ids.include?(g.id) }
        @finished << f
        @mailed << m
        @started << s
        @not_started << n
        @graders << {id: i, grader: g, groups: grader_groups}
        i = i + 1
      end

      # TODO: should we remove this?
      # Koodiaapinen hack. Remove after 2016.
      #sort_mode = if @exercise.id == 208 || @exercise.id == 289
      #              :name
      #             else
      #              :id
      #            end

      sort_mode = :id

      @groups = @groups.to_a

      case sort_mode
        when :name
          @groups.sort! { |a, b| Group.compare_by_name(a, b) }
        when :earliest_submission
          @groups.sort! { |a, b| Group.compare_by_submission_time(a, b, @exercise, :earliest) }
        when :latest_submission
          @groups.sort! { |a, b| Group.compare_by_submission_time(a, b, @exercise, :latest) }
        when :status
          @groups.sort! { |a, b| Group.compare_by_submission_status(a, b, @exercise) }
        when :id
          @groups.sort! { |a, b| a.id <=> b.id }
        else
          @groups.sort! { |a, b| a.id <=> b.id }
      end

      render action: 'submissions', layout: params[:view] == 'thumbnails' ? 'wide-new' : 'fluid-new'
    else
      # Student's or assistant's view
      @is_assistant = @course_instance.has_assistant(current_user)

      # Find reviews assigned to the user
      # TODO: move to model
      explicitly_assigned_groups = Set.new(current_user.assigned_group_ids)
      @assigned_groups = Set.new

      # Find peer groups whose submissions the user can view
      @viewable_peer_groups = Set.new

      @exercise.groups_with_submissions.order('submissions.created_at DESC, reviews.id').each do |group|
        @assigned_groups << group if explicitly_assigned_groups.include?(group.id) || @exercise.show_all_submissions_to?(current_user)

        group.submissions.each do |submission|
          @viewable_peer_groups << group if @exercise.collaborative_mode != '' && !group.users.include?(current_user)

          submission.reviews.each do |review|
            @assigned_groups << group if review.user == current_user
          end
        end
      end

      @assigned_groups = @assigned_groups.to_a
      @viewable_peer_groups = @viewable_peer_groups.to_a

      if @viewable_peer_groups.length > 2
        @viewable_peer_groups.shuffle!
        @viewable_peer_groups.sort! { |g1, g2| g1.submissions.sum { |s| s.reviews.length } <=> g2.submissions.sum { |s| s.reviews.length } }
        top = @viewable_peer_groups[-2..-1].reverse
        rest = @viewable_peer_groups[0..-3]
        @viewable_peer_groups = top + rest
      end

      # Find groups of the user
      @available_groups = Group.where('course_instance_id=? AND user_id=?', @course_instance.id, current_user.id).joins(:users).all

      # How many submissions does the user have?
      # FIXME: this is a quick hack, probably inefficient
      @own_submission_count = 0
      @available_groups.each do |group|
        submissions = group.submissions.where(exercise_id: @exercise.id)
        @own_submission_count += submissions.size
      end

      render action: 'my_submissions', layout: 'wide-new'
    end

#     memory_usage = `ps -o rss= -p #{$$}`.to_i
#     logger.debug "Memory consumption: #{memory_usage / 1048576} MB"

    log "exercise view #{@exercise.id}"
  end

  # GET /exercises/new
  def new
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @exercise = Exercise.new

    log "create_exercise view #{@course_instance.id}"
  end

  # POST /exercises
  def create
    @exercise = Exercise.new(exercise_params)
    @exercise.course_instance_id = params[:course_instance_id]
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if @exercise.save
      @exercise.initialize_example

      #flash[:success] = 'Assignment was successfully created.'
      redirect_to @exercise
      log "create_exercise success #{@exercise.id}"
    else
      render action: 'new'
      log "create_exercise fail #{@exercise.errors.full_messages.join('. ')}"
    end
  end

  # GET /exercises/1/edit
  def edit
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    log "edit_exercise view #{@exercise.id}"
  end

  # PUT /exercises/1
  def update
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if @exercise.update(exercise_params)
      #flash[:success] = 'Assignment was successfully updated.'
      redirect_to @exercise
      log "edit_exercise success #{@exercise.id}"
    else
      render action: 'edit'
      log "edit_exercise fail #{@exercise.errors.full_messages.join('. ')}"
    end
  end

  # DELETE /exercises/1
  # DELETE /exercises/1.xml
  def destroy
    @exercise = Exercise.find(params[:id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    log "delete_exercise success #{@exercise.id}"
    @exercise.destroy

    respond_to do |format|
      format.html { redirect_to @course_instance }
      format.xml  { head :ok }
    end
  end

  def results
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    options = {}
    if params[:include] == 'all'
      options[:include_all] = true
    else
      options = begin
        JSON.parse(@exercise.grading_mode || '{}')
        rescue Exception => e
          logger.warn "Invalid grading mode for exercise #{@exercise.id}: #{@exercise.grading_mode}\n#{e}"
          {}
      end
      options[:include_peer_review_count] = @exercise.peer_review?
    end

    groups = Group.where(course_instance_id: @exercise.course_instance_id).includes([{submissions: [reviews: :user]}, {group_members: :user}])
    @results = @exercise.results(groups, options)

    # Sort the result
    case params[:sort]
    when 'lti-user-id'
      @results.sort! { |a, b| (a[:member].user ? a[:member].user.lti_user_id || '' : '').downcase <=> (b[:member].user ? b[:member].user.lti_user_id || '' : '').downcase }
    when 'student-id'
      @results.sort! { |a, b| (a[:member].studentnumber || '').downcase <=> (b[:member].studentnumber || '').downcase }
    when 'first-name'
      @results.sort! { |a, b| (a[:member].firstname || '').downcase <=> (b[:member].firstname.downcase || '') }
    when 'last-name'
      @results.sort! { |a, b| (a[:member].lastname || '').downcase <=> (b[:member].lastname || '').downcase }
    when 'email'
      @results.sort! { |a, b| (a[:member].email || '').downcase <=> (b[:member].email || '').downcase }
    when 'grade'
      @results.sort! { |a, b| Review.compare_grades(a[:grade], b[:grade]) }
    when 'grade-range'
      @results.sort! { |a, b| (b[:grade_range] || 0) <=> (a[:grade_range] || 0) }
    when 'peer-review-count'
      #@results.sort! { |a, b| (a[:created_peer_review_count] || 0) <=> (b[:created_peer_review_count] || 0) }
      @results.sort! { |a, b| (a[:finished_peer_review_count] || 0) <=> (b[:finished_peer_review_count] || 0) }
    when 'notes'
      @results.sort! { |a, b| (a[:notes] || '') <=> (b[:notes] || '') }
    when 'reviewer'
      @results.sort! { |a, b| (a[:reviewer].nil? ? '' : (a[:reviewer].lastname || '').downcase) <=> (b[:reviewer].nil? ? '' : (b[:reviewer].lastname || '').downcase) }
    when 'submitted-at'
      @results.sort! { |a, b| (a[:submission].nil? ? 0 : a[:submission].created_at.to_i) <=> (b[:submission].nil? ? 0 : b[:submission].created_at.to_i) }
    else
      @results.sort! { |a, b| (a[:member].studentnumber || '') <=> (b[:member].studentnumber || '') }
    end

    #@results.sort! { |a, b| (a[:notes]) <=> (b[:notes]) }

    log "results #{@exercise.id}#{params[:include] == 'all' ? ' all' : ''}"

    render action: :results, layout: 'fluid-new'
  end

  def student_results
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    @results = @exercise.student_results
    log "student_results #{@exercise.id}"
  end

  def aplus_results
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    render text: @exercise.aplus_results.to_json

    log "aplus_results #{@exercise.id}"
  end

  def statistics
    @exercise = Exercise.find(params[:id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    graders = @course.teachers + @course_instance.assistants

    @histograms = []

    # All graders
    histogram = @exercise.grade_distribution()
    total = 0
    histogram.each { |pair| total += pair[1] }
    @histograms << {grader: 'All', histogram: histogram, total: total}

    # Each grader
    graders.each do |grader|
      histogram = @exercise.grade_distribution(grader)
      total = 0
      histogram.each { |pair| total += pair[1] }

      @histograms << {grader: grader.name, histogram: histogram, total: total}
    end
  end

  # Mails selected submissions and reviews
  def send_reviews
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Collect selected review ids
    review_ids = (params[:reviews_checkboxes] || []).reject { |id, value| value != '1' }.keys
    send_grade_mode = ["best_grade", "average"].include?(params[:send_grade_mode]) ? params[:send_grade_mode] : nil
    @exercise.deliver_reviews(review_ids, send_grade_mode)

    redirect_to @exercise
    log "send_reviews #{@exercise.id} #{review_ids.size}"
  end

  # Removes selected submissions and reviews
  #   def remove_selected_submissions
  #     @exercise = Exercise.find(params[:eid])
  #     load_course
  #
  #     # Authorization
  #     return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
  #
  #     # Iterate through submissions checkboxes
  #     if params[:submissions_checkboxes]
  #       params[:submissions_checkboxes].each do |id, value|
  #         Submission.destroy(id) if value == '1'
  #       end
  #     end
  #
  #     # Iterate through reviews checkboxes
  #     if params[:reviews_checkboxes]
  #       params[:reviews_checkboxes].each do |id, value|
  #         Review.destroy(id) if value == '1'
  #       end
  #     end
  #
  #     render partial: 'group', collection: @exercise.groups
  #   end


  # Assigns selected submissions to the selected user
  def assign
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Select checked submissions
    submission_ids = Array.new
    if params[:submissions_checkboxes]
      params[:submissions_checkboxes].each do |id, value|
        submission_ids << Integer(id) if value == '1'
      end
    end

    # Select checked reviews
    review_ids = Array.new
    if params[:reviews_checkboxes]
      params[:reviews_checkboxes].each do |id, value|
        review_ids << Integer(id) if value == '1'
      end
    end

    #exclusive = params[:exclusive] == 'true'

    if params[:assign]
      # Assign
      if params[:assistant] == 'assistants'
        @exercise.assign(submission_ids, @course_instance.assistant_ids)
      elsif params[:assistant] == 'students'
        @exercise.assign(submission_ids, @course_instance.student_ids)
      else
        @exercise.assign(submission_ids, [Integer(params[:assistant])])
      end

      redirect_to @exercise
    elsif params[:mail]

    elsif params[:delete]
      @reviews = Review.find(review_ids)

      render :delete_reviews
    else
      redirect_to @exercise
    end
  end


  def delete_reviews
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Read review list
    counter = 0
    if params[:reviews]
      review_ids = Array.new
      params[:reviews].each do |id, value|
        review_ids << Integer(id) if value == '1'
      end

      # Delete reviews
      reviews = Review.find(review_ids)
      reviews.each do |review|
        review.destroy
      end

      counter = review_ids.size
    end

    redirect_to @exercise, flash: {success: "#{counter} reviews deleted"}
  end

  def batch_assign
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    # Process CSV
    if params[:paste]
      counter = @exercise.batch_assign(params[:paste])
      flash[:success] = "#{counter} new assignments"
      redirect_to @exercise
    end

    if params[:csv] && params[:csv][:file]
      counter = @exercise.batch_assign(params[:csv][:file].read)
      flash[:success] = "#{counter} new assignments"
      redirect_to @exercise
    end
  end

  def archive
    @exercise = Exercise.find(params[:exercise_id])
    load_course

    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    begin
      archive_path = @exercise.archive(only_latest: true)
      send_file archive_path, type: 'application/x-gzip', filename: @exercise.archive_filename
    ensure
      # TODO: delete tempdir and archive
      #File.delete(archive_path)
    end
  end

  def create_example_submissions
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    authorize! :update, @course_instance

    example_groups_count = 5
    # Try to find existing example groups
    groups = @course_instance.get_example_groups(example_groups_count)

    if groups.count < example_groups_count
      # Create new example groups
      groups = @course_instance.create_example_groups(example_groups_count)
      if groups.count == 0  # If no example group exists nor has been created
        flash[:warning] = "Cannot generate example submissions."
      end
    end
    @exercise.create_example_submissions_for(groups)

    redirect_to @exercise

    log "create_example_submissions #{@exercise.id}"
  end

  # Assign to current user and start review
  def create_peer_review
    @exercise = Exercise.find(params[:exercise_id])
    load_course
    return access_denied unless @course_instance.has_student(current_user) || @course_instance.has_assistant(current_user) || @course.has_teacher(current_user)

    # TODO: move most of this to model
    review = nil
    submission = nil
    Exercise.transaction do
      # Count the reviews of each group. Skip user's own groups.
      # result: [ {group: Group, count: integer}, ... ]
      review_counts = []
      @exercise.groups_with_submissions.each do |group|
        next if group.users.include?(current_user)

        # Find the latest submission
        latest_submission = nil
        group.submissions.each do |submission|
          next unless submission.exercise_id == @exercise.id
          latest_submission = submission if !latest_submission || submission.created_at > latest_submission.created_at
        end
        next unless latest_submission
        submission = latest_submission

        skip = false
        review_count = 0

        submission.reviews.each do |review|
          review_count += 1 unless review.status == 'invalidated'

          # User cannot review the same group twice
          skip = true if review.user == current_user
        end
        next if skip

        review_counts << {group: group, count: review_count, submission: latest_submission}
      end

      if review_counts.empty?
        flash[:warning] = t('exercises.nothing_to_peer_review')
        redirect_to @exercise
        return
      end

      # Select the group with the least reviews
      review_counts.shuffle!
      review_counts.sort! { |a, b| a[:count] <=> b[:count] }
      group = review_counts.first

      review = group[:submission].assign_to(current_user, session[:lti_launch_params])
    end

    redirect_to edit_review_path(review)
    log "create_peer_review #{submission.id},#{@exercise.id}"
  end
  
  # A+ calls this. Redirects to submit to exercise if exercise exists. Otherwise creates the exercise and then redirects to it.
  def aplus_exercise
    # Check that neccessary lti related params are included in the request
    if params['oauth_consumer_key'].blank? || params[:context_id].blank? || params[:resource_link_id].blank?
      @heading = 'Insufficient parameters'
      render template: 'shared/error', layout: 'wide'
      return false
    end
    # Find the course_instance
    @course_instance = CourseInstance.where(lti_consumer: params['oauth_consumer_key'], lti_context_id: params[:context_id]).first
    unless @course_instance
      @heading = 'This LTI course is not configured'
      logger.warn "LTI login failed. Could not find a course instance with lti_consumer=#{params['oauth_consumer_key']}, lti_context_id=#{params[:context_id]}"
      render template: 'shared/error'
      return false
    end
    # Find exercise and create one if it does not exist yet
    @exercise = Exercise.where(course_instance_id: @course_instance.id, lti_resource_link_id: params[:resource_link_id]).first
    unless @exercise
      sub_url = params[:submission_url]
      #sub_url = sub_url.sub('plus', remote_ip) # To be used when running Rubyric and aplus locally (change ip to fit your aplus)
      exercise_name = JSON.load(RestClient.get(sub_url))
      exercise_name = exercise_name.is_a?(Hash) ? exercise_name["exercise"] : nil
      exercise_name = exercise_name.is_a?(Hash) ? exercise_name["display_name"] : nil
      if !exercise_name
        @heading = 'Failed to get exercise information from A+'
        render template: 'shared/error', layout: 'wide'
        return false
      end
      submit_type      = 'file'
      review_mode      = 'annotation'
      resource_link_id = params[:resource_link_id]
      @exercise = Exercise.new(course_instance: @course_instance, name: exercise_name,
                               submission_type: submit_type,      review_mode: review_mode,
                               lti_resource_link_id: resource_link_id)
      if !@exercise.save
        @heading = 'Failed to configure exercise'
        render template: 'shared/error', layout: 'wide'
        return false
      end
    end
    redirect_to aplus_get_path(@exercise, request.parameters)
  end

  private

  def exercise_params
    # TODO: rename groupsizemin to group_size_min
    # TODO: rename groupsizemax to group_size_max
    params.require(:exercise).permit(:course_instance_id, :name, :deadline, :groupsizemin, :groupsizemax, :submission_type, :allowed_extensions, :review_mode,
                                     :grader_can_email, :submit_pre_message, :peer_review_goal, :peer_review_timing, :collaborative_mode, :anonymous_graders,
                                     :anonymous_submissions, :lti_resource_link_id, :lti_resource_link_id_review, :lti_resource_link_id_feedback,
                                     :reviewers_see_all_submissions)
  end
end
