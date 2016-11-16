class Group < ActiveRecord::Base
  belongs_to :exercise
  belongs_to :course_instance

  has_many :group_members, dependent: :destroy
  has_many :users, through: :group_members

  has_many :submissions, {order: 'created_at DESC', dependent: :destroy}
  has_many :submission_summaries, select: 'submissions.id, submissions.created_at, submissions.filename, submissions.extension', class_name: 'Submission', order: 'created_at DESC', dependent: :destroy

  has_many :group_reviewers, dependent: :destroy
  has_many :reviewers, through: :group_reviewers, source: :user, class_name: 'User'

  #accepts_nested_attributes_for :group_members, :reject_if => proc { |attributes| attributes['email'].blank? }
  validate :require_group_members
  before_create :generate_token

  attr_accessor :url # Needed for JSON serialization

  def name
    self.group_members.collect { |member| member.user ? member.user.name : member.email }.join(', ')
  end

  def names_with_studentnumbers
    self.group_members.collect do |member|
      if member.user
        if member.user.studentnumber.blank? && member.user.name.blank?
          if member.user.email.blank?
            member.email
          else
            member.user.email
          end
        else
          text = ''
          text << "#{member.user.name} " unless member.user.name.blank?
          text << "(#{member.user.studentnumber})" unless member.user.studentnumber.blank?
          text
        end
      else
        member.email
      end
    end.join(', ')
  end

  def require_group_members
    errors.add(:base, 'Group cannot be empty') if self.group_members.empty?
  end

  # Generates a unique token
  def generate_token
    begin
      self.access_token = Digest::SHA1.hexdigest([Time.now, rand].join)
    end while Group.exists?(access_token: self.access_token)
  end

  def has_member?(user)
    user && users.include?(user)
  end

  def has_reviewer?(user)
    user && reviewers.include?(user)
  end

  def add_member(user)
    return if self.users.include?(user)

    member = GroupMember.new(email: user.email, studentnumber: user.studentnumber)
    member.group = self
    member.user = user
    member.save(validate: false)

    self.course_instance.students << user unless self.course_instance.students.include?(user)
  end

  # members: array of GroupMembers
  def add_members(members, exercise)
    members.each do |member|
      user = User.find_by_email(member.email)

      if user
        member.user = user
        member.save
        self.course_instance.students << user unless self.course_instance.students.include?(user)
      else
        member.save
        GroupMember.delay.send_invitation(member.id, exercise.id)
      end
    end
  end

  def self.compare_by_name(a, b)
    # Try to find a memebr with a User and a name
    a_member = a.group_members.max_by { |member| member.user ? (member.user.lastname.blank? ? 1 : 2) : 0 }
    b_member = b.group_members.max_by { |member| member.user ? (member.user.lastname.blank? ? 1 : 2) : 0 }

    # Empty groups last
    return 1 if !a_member
    return -1 if !b_member

    a_user = a_member.user
    b_user = b_member.user
    a_name = a_user ? a_user.lastname : nil
    b_name = b_user ? b_user.lastname : nil
    a_name = nil if a_name == ''
    b_name = nil if b_name == ''

    # Sort by name if both have a name
    return a_user.lastname.downcase <=> b_user.lastname.downcase if a_user && b_user && a_name && b_name

    # Sort by email if neither has a name
    return (a_member.email || '').downcase <=> (b_member.email || '').downcase if !a_name && !b_name

    # If one has a name and the other doesn't, put those without a name last
    return 1 if !a_name
    return -1 if !b_name

    return 0
  end

  # exercise: Exercise or exercise_id
  # mode: :earliest or :latest
  def self.compare_by_submission_time(a, b, exercise, mode = :earliest)
    exercise_id = if exercise.is_a? Exercise
                    exercise.id
                  else
                    exercise
                  end

    a_extreme, b_extreme = [a, b].map do |group|
      extreme_submission = nil
      group.submissions.each do |submission|
        next if submission.exercise_id != exercise_id
        if mode == :earliest
          # TODO; handle ties
          extreme_submission = submission if !extreme_submission || submission.created_at < extreme_submission.created_at
        else
          extreme_submission = submission if !extreme_submission || submission.created_at > extreme_submission.created_at
        end
      end

      extreme_submission ? extreme_submission.created_at : nil
    end

    return 1 if !a_extreme
    return -1 if !b_extreme

    a_extreme <=> b_extreme
  end


  # exercise: Exercise or exercise_id
  # mode: :earliest or :latest
  def self.compare_by_submission_status(a, b, exercise)
    exercise_id = if exercise.is_a? Exercise
                    exercise.id
                  else
                    exercise
                  end

    a_extreme, b_extreme = [a, b].map do |group|
      extreme_status = nil
      group.submissions.each do |submission|
        next if submission.exercise_id != exercise_id

        submission.reviews.each do |review|
          # FIXME: compare by semantic value
          extreme_status = (review.status || '') if !extreme_status || (review.status || '') < (extreme_status || '')
        end
      end

      extreme_status || ''
    end

    # FIXME: compare by semantic value
    a_extreme <=> b_extreme
  end
end
