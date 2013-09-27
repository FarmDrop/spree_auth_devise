Spree::Api::UsersController.class_eval do

  include EmailJobHelper
  include Devise::Controllers::Helpers


  def index
    @users = Spree.user_class.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
    respond_with(@users)
  end

  def show
    @users = Spree.user_class.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
    respond_with(user)
  end

  def new
  end

  def create

    @user = Spree::User.new(user_params)
    if @user.save

      @address = Spree::Address.new(params["user"]["bill_address"])
      #TODO: HACK - tidy country default
      @address.country = Spree::Country.find(44)

      if @address.save

        @user.bill_address = @address

        if user_params["fb_auth_token"].present? && user_params["g_auth_token"].present?
          @user.generate_auth_token
        else
          @user.g_auth_token = user_params["g_auth_token"]
          @user.fb_auth_token = user_params["fb_auth_token"]
        end

        @user.set_role(user_params["role"])
        add_user_to_mailchimp(@user, @address)
        send_user_signup_confirmation(@user, @address)
        sign_in(:spree_user, @user)
        @user.save

        respond_with(@user, :status => 200, :default_template => :show_token)

      else
        @user.destroy
        respond_with(@address, :status => 422, :default_template => :address_error)
      end
    else
      respond_with(@user, :status => 422, :default_template => :error)
    end

  end

  def update
    authorize! :update, user
    if user.update_attributes(user_params)
      respond_with(user, :status => 200, :default_template => :show)
    else
      invalid_resource!(user)
    end
  end

  def destroy
    authorize! :destroy, user
    user.destroy
    respond_with(user, :status => 204)
  end


  def register

  end


  def refer

    require 'mandrill'
    m = Mandrill::API.new

    @refer = params[:referrer]

    params[:referee].each do |i|

      if (!i['email'].to_s.empty?)

        message = {
            :subject => "Your friend " + @refer["firstname"] + " has recommended FarmDrop",
            :from_name => "FarmDrop",
            :from_email => "hello@farmdrop.co.uk",
            :to => [
                {
                    :email => i['email'],
                    :name => i['name']
                }
            ],
            :global_merge_vars => [{:name => "referee", :content => i["name"]}, {:name => "referrer", :content => @refer["firstname"]}]
        }

        sending = m.messages.send_template('Referral', [{:name => "referee", :content => i["name"]}], message)

        @referral = Referral.new()

      end
    end
  end


  private


  def check_token(user,token)
    user.g_auth_token ||= token
    user.fb_auth_token ||= token
  end



  def user
    @user ||= Spree.user_class.accessible_by(current_ability, :read).find(params[:id])
  end

  def user_params
    params.require(:user).permit(permitted_user_attributes)
  end


end
