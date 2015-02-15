register Sinatra::AssetPack

assets {
  serve '/bower_components',  from: 'bower_components'
  serve '/assets',            from: 'assets'
  serve '/fonts',             from: 'bower_components/fontawesome/fonts'

  # The second parameter defines where the compressed version will be served.
  # (Note: that parameter is optional, AssetPack will figure it out.)
  # The final parameter is an array of glob patterns defining the contents
  # of the package (as matched on the public URIs, not the filesystem)
  js :app_js, '/js/app.js', [
    '/bower_components/jquery/dist/jquery.min.js',
    '/bower_components/bootstrap/dist/js/bootstrap.min.js'
  ]
  
  css :app_css, '/css/style.css', [
    #'/bower_components/bootstrap/dist/css/bootstrap.min.css',
    '/assets/style.css'
  ]

  prebuild true
  #css_compression :less
  #js_compression  :jsmin    # :jsmin | :yui | :closure | :uglify
  #css_compression :simple   # :simple | :sass | :yui | :sqwish
}

#######################################
# Routes
#

before do
    login User.find(session[:user]) if User.exists? session[:user]
end

get '/' do
    # It's convenient to write the Readme in markdown, but silly to re-render it each time.
    # Instead, we cache it in tmp until the dyno gets killed or the Readme source is modified
    if (File.exists?('tmp/Readme.html') and File.mtime('tmp/Readme.html') >= File.mtime('Readme.md'))
        @readme = File.read('tmp/Readme.html')
    else
        render_options = {with_toc_data: true}
        extensions = {autolink: true,
            fenced_code_blocks: true,
            lax_spacing: true,
            hard_wrap: true,
            tables: true}
        md = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(render_options), extensions)
        @readme = md.render(File.read('Readme.md'))
        Dir.mkdir 'tmp' unless Dir.exist? 'tmp'
        File.open('tmp/Readme.html', 'w') {|f| f.write(@readme)}
        puts "Regenerated tmp/Readme.html"
    end
    haml :landing
end

get '/examples' do
    title "Examples"
    @examples = Example.all
    haml :examples
end

get '/examples/:id' do
    @example = Example.find(params[:id])
    title @example.name
    haml :example
end

get '/users/new' do
    title 'Sign Up'
    # log out the current user
    logout
    haml :signup
end

post '/users/new' do
    title 'Sign Up'
    user = User.create(params)
    if !user.valid?
        flash.now[:info] = user.errors.map{|attr, msg| "#{attr.to_s.humanize} #{msg}"}.join("<br>")
        haml :signup, locals: {email: params[:email]}
    else
        login user
        redirect '/'
    end
end

get '/logout' do
    logout
    redirect '/'
end

get '/login' do
    title 'Login'
    haml :login
end

post '/login' do
    title 'Login'
    user = User.find_by_email(params[:email])
    if user and user.authenticate(params[:password])
        login user
        redirect URI.unescape(params[:dest] || '/')
    else
        flash.now[:info] = "Sorry, wrong username or password"
        haml :login, locals: {email: params[:email]}
    end
end

get '/account' do
    require_login
    title 'Account Settings'
    haml :account_settings
end

post '/account' do
    require_login
    if !@user.authenticate(params[:current_password])
        flash.now[:warning] = "Current password was wrong"
        return haml :account_settings
    end
    @user.update(params[:user])
    if @user.valid?
        flash.now[:info] = "Account info updated"
    else
        flash.now[:warning] = @user.errors.map{|attr, msg| "#{attr.to_s.humanize} #{msg}"}.join("<br>")
    end
    haml :account_settings
end

get '/account/forgot_password' do
    haml :forgot_password
end

post '/account/forgot_password' do
    user = User.find_by_email(params[:email])
    if user
        user.password_reset();
        reset_link = "#{baseurl}/account/forgot_password/#{user.password_reset_token}"
        mail_with_template(user.email,
            "Forgot Password Link from #{settings.app_name}",
            "Someone (hopefully you) requested a password reset on #{settings.app_name}. To reset your password, go to #{reset_link}.")
        flash.now[:info] = "An email has been sent to #{user.email} with instructions to reset your password."
    else
        flash.now[:warning] = "We couldn't find an account matching that email."
    end
    haml :forgot_password
end

get '/account/forgot_password/:token' do
    user = User.find_by(password_reset_token: params[:token])
    if (user == nil)
        flash[:warning] = "That password reset link has expired. Sorry!"
        redirect '/'
    end
    haml :password_reset, locals: {user: user}
end

post '/account/forgot_password/:token' do
    user = User.find_by(password_reset_token: params[:token])
    if (user == nil)
        flash[:warning] = "That password reset link has expired. Sorry!"
        redirect '/'
    end
    if params[:password].blank?
        flash.now[:warning] = "Password cannot be blank"
        return haml :password_reset, locals: {user: user}
    end

    user.update(password: params[:password], password_confirmation: params[:password_confirmation])

    if user.errors.size > 0
        flash.now[:warning] = user.errors.map{|attr, msg| "#{attr.to_s.humanize} #{msg}"}.join("<br>")
        haml :password_reset, locals: {user: user}
    else
        user.update(password_reset_token: nil)
        flash[:info] = "Password updated. You may now log in with your new password."
        redirect '/login'
    end
end


get '/payment' do
    title 'Payment Example'
    haml :payment
end

# process a charge for something
# see https://stripe.com/docs/tutorials/charges for details
post '/charge/:item' do
    # Get the credit card details submitted by the form
    token = params[:stripeToken]

    # The cost of your item should probably be stored in your model
    # or something. Everything is specified in cents
    charge_amounts = {'example_charge' => 500, 'something_else' => 200};

    # Create the charge on Stripe's servers - this will charge the user's card
    begin
        charge = Stripe::Charge.create(
            :amount => charge_amounts[params[:item]], # amount in cents.
            :currency => "usd",
            :card => token,
            :description => "description for this charge" # this shows up in receipts
            )
        title 'Payment Complete'
    rescue Stripe::CardError => e
        title 'Card Declined'
        flash.now[:warning] = 'Your card was declined'
        # The card has been declined
        puts "CardError"
    rescue Stripe::InvalidRequestError => e
        title 'Invalid Request'
        flash.now[:warning] = 'Something went wrong with the transaction. Did you hit refresh? Don\'t do that.'
    rescue => e
        puts e
    end

    haml :charge
end

#######################################
# Helpers

helpers do
    # set the page title
    def title(t)
        @title = "#{t} | #{settings.app_name}"
    end

    # bootstrap glyphicons
    def glyph(i)
        "<span class='glyphicon glyphicon-#{i}'></span>"
    end

    #fontawesome icons
    def fa(i)
        "<i class='fa fa-#{i}'></i>"
    end

    def login(u)
        @user = u
        session[:user] = u.id
    end

    def logout
        @user = nil
        session.clear
    end

    def require_login
        unless @user
            flash[:warning] = 'You must be logged in to view this page'
            redirect "/login?dest=#{URI.escape(request.fullpath)}", 303
            halt 403, haml(:unauthorized)
        end
    end

    # create a checkout button to charge the user
    # amount should be the charge amount in cents
    # amount is required
    # options takes the following keys
    # name: 'A name for the charge'
    # description: 'A description for the charge'
    # image: 'A url to an image to display'
    # item: 'Item to be passed to the charge callback'
    def checkout_button(amount, options = {})
        defaults = {"data-amount" => amount,
            "data-description" => "2 widgets ($20.00)",
            "data-image" => "//placehold.it/128",
            "data-key" => ENV['STRIPE_KEY_PUBLIC'],
            "data-name" => settings.app_name,
            :src => "https://checkout.stripe.com/checkout.js"}

        defaults['data-name'] = options[:name] if options[:name]
        defaults['data-description'] = options[:description] if options[:description]
        defaults['data-image'] = options[:image] if options[:image]

        haml_tag :form, {action: "/charge/#{options[:item]}", method: 'POST'} do
            haml_tag 'script.stripe-button', defaults
        end
    end

    # mail helper for convenience
    def mail_with_template(to, subject, message, button = nil)
        html_message = erb :email_template, locals: {message_body: message, message_title: subject, button: button}
        premailer = Premailer.new(html_message, with_html_string: true, css_to_attributes: false)
        html_message_inlined = premailer.to_inline_css

        m = Mail.new
        m.from = "#{settings.app_name} <#{ENV['ADMIN_EMAIL']}>"
        m.to = to
        m.subject = subject

        # m.text_part = Mail::Part.new do
        #     body "foobar"
        # end

        m.html_part = Mail::Part.new do
            content_type 'text/html; charset=UTF-8'
            body html_message_inlined
        end

        m.deliver
    end
    def baseurl
        if defined? settings.baseurl
            settings.baseurl
        else
            request.base_url
        end
    end
end
