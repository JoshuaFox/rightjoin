class Ambassador < ActiveRecord::Base
  serialize :profile_links_map, JSON
  
  attr_accessible :avatar, :email, :employer_id, :first_name, :last_name, :profile_links_map, :status, :title
  
  # TODO: remove uid and provider columns, but only after production DB is migrated!!!
  
  MAX_FIRST_NAME_LEN = 20
  MAX_LAST_NAME_LEN = MAX_FIRST_NAME_LEN
  MAX_TITLE_LEN = 40

  validates :email, :presence => true, :format=> { :with=> Constants::VALID_EMAIL_REGEX }, :length => { :maximum => 255 }
  validates :employer_id, :presence => true
  
  
  validates :first_name, :presence => true, :length => { :maximum => MAX_FIRST_NAME_LEN }
  validates :last_name, :length => { :maximum => MAX_LAST_NAME_LEN }
  
  validates :title, :length => { :maximum => MAX_TITLE_LEN }
  before_save { |a| a.email = a.email.downcase }
  
  belongs_to :employer
  belongs_to :auth
  has_many :shares, :dependent => :nullify
  has_many :infointerviews, :dependent => :nullify, :foreign_key => :referred_by
  
  INVITED = 10 # not used
  ACTIVE = 20
  CLOSED = 0 # for :status
  
  scope :only_active, where("status = ?", Ambassador::ACTIVE)
  
  def status_one_of?(*statuses)
    statuses.include?(status)
  end 
  
  def reference_num(scramble = true)
    Utils.reference_num(self, scramble)
  end
  
  def self.find_by_ref_num(ref_num, scramble = true)
    Utils.find_by_reference_num(Ambassador, ref_num, scramble)  
  end
  
  def shares_statistics
    Share.joins(:ambassador).where("ambassadors.id = ?", id).group("ambassadors.id").select("ambassadors.id as ambassador_id, count(*) as shares_count, sum(shares.click_counter) as clicks_count, sum(shares.lead_counter) as leads_count")
  end  
  
  def avatar_path
    Rails.application.routes.url_helpers.ambassador_avatar_path(self.reference_num, :timestamp => self.updated_at.to_i.to_s(16)) 
  end
  
  def profile_link
    link = ""
    unless self.profile_links_map.blank?
      resource, link = self.profile_links_map.first
    end
    return link
  end
  
  def init_from_oauth!(auth)
    self.email = auth.email
    self.first_name = auth.first_name
    self.last_name = auth.last_name
    self.title = auth.title
    
    # always override image, use the last one user loged in with (ugly)
    self.avatar = auth.avatar
    self.avatar_content_type = auth.avatar_content_type
    
    self.profile_links_map ||= {}

    auth.profile_links_map.each do |key ,val|
      if self.profile_links_map.size < AmbassadorsController::MAX_NUM_PROFILE_LINKS 
        self.profile_links_map[key] = val unless val.nil?
      end
    end
    
    self.auth = auth
  end
  
  def self.share_description(job)
     "We're looking for #{Utils::indefinite_article_and_noun(job.position_name)}. See our ad and ping us to be in touch."
  end
  
  def self.share_title(job)
    "Come work with me at #{job.company_name}."
  end
  def self.share_summary(job)
    "Connect to #{ job.company_name } and talk with us about our work culture."
  end
   
end
