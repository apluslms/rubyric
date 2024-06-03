class CourseInstances::GroupsController < GroupsController
  before_action :login_required

  layout 'application'
  
  def index
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course
    authorize! :update, @course_instance

    groups = @course_instance.groups.includes([:users, :reviewers])
    groups.each do |group|
      group.url = edit_course_instance_group_path(:course_instance_id => @course_instance.id, :id => group.id)
    end
    
    #user_ids = groups.collect {|group| group.user_ids }
    user_ids = []
    user_ids << @course.teacher_ids
    user_ids << @course_instance.assistant_ids
    user_ids << @course_instance.student_ids
    users = User.find(user_ids)

    exercises = @course_instance.exercises
    submissions = Submission.where(exercise_id: exercises.ids)

    @groups_json = {
      groups: groups.as_json(
                             :only => [:id],
                             :include => [:group_members => {
                                                        :only => [:email],
                                                        :methods => [:name, :studentnumber]
                                                         }
                                          ],
                             :methods => [:reviewer_ids, :url]
      ),
      users: users.as_json(:only => [:id, :studentnumber, :email, :firstname, :lastname]),
      students: @course_instance.student_ids,
      assistants: @course_instance.assistant_ids,
      teachers: @course.teacher_ids,
      submissions: submissions.as_json(:only => [:id, :group_id, :exercise_id]),
      exercises: exercises.as_json(:only => [:id, :name])
    }
    
#     respond_to do |format|
#       format.html { }
#       format.json { render :json => response }
#     end
  end
  
  def update
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course
    authorize! :update, @course_instance
    
    @course_instance.set_assignments(params[:assignments])
    
    respond_to do |format|
      format.html { redirect_to @course_instance }
      format.json { head :ok }
    end
  end

  def batch
    @course_instance = CourseInstance.find(params[:course_instance_id])
    load_course
    authorize! :update, @course_instance

    @reported_ambiguous_keys = []
    @reviewers_not_found = []
    
    if params[:paste]
      batch_create_groups_errors = @course_instance.batch_create_groups(params[:paste])
      @reported_ambiguous_keys = batch_create_groups_errors[:reported_ambiguous_keys]
      @reviewers_not_found = batch_create_groups_errors[:reviewers_not_found]
      if @reported_ambiguous_keys.empty? and @reviewers_not_found.empty?
        redirect_to course_instance_groups_path
      end
      log "batch_groups upload"
    else
      log "batch_groups view"
    end
  end
  
end
