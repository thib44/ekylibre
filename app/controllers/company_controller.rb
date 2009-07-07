require "rexml/document"

class CompanyController < ApplicationController

  def index
    @company = @current_company
    @title = {:value=>@company.name}
  end

  def update
    @company = @current_company
    if request.post?
      if @company.update_attributes(params[:company])
        redirect_to_back
      end
    end
    @title = {:value=>@company.name}
  end

  def backup
    company = @current_company
    version = (ActiveRecord::Migrator.current_version rescue 0)
    puts version
    filename = "backup-"+@current_company.code.lower+"-"+Time.now.strftime("%Y%m%d-%H%M%S")
    file = "#{RAILS_ROOT}/tmp/#{filename}.xml.gz"
    doc = REXML::Document.new
    doc << REXML::XMLDecl.new
    backup = doc.add_element 'backup', 'version'=>version
    root = backup.add_element 'company', company.attributes
    reflections = Company.reflections
    for name in reflections.keys.collect{|x| x.to_s}.sort
      reflection = reflections[name.to_sym]
      if reflection.macro==:has_many
        klass = reflection.class_name.constantize
        # table = root.add_element('table', )
        columns = klass.column_names.sort
        for x in company.send(name.to_sym)
          puts x.id if x.id%200==0
          root.add_element('r', x.attributes.merge('_reflection'=>name))
        end
      end
    end

    stream = doc.to_s #"backup "*1000
    send_data stream, :filename=>filename+".xml", :disposition=>'attachment', :type=>'text'
    # send_data Zlib::Deflate.deflate(stream), :filename=>filename
    # Zlib::GzipWriter.open(file) { |gz| gz.write(stream) }
    # send_file file
  end

  def restore
    if request.post?
      company = @current_company
      # Récupération du fichier
      backup = params[:backup][:path]
      file = "#{RAILS_ROOT}/tmp/#{backup.original_filename}.#{rand.to_s[2..-1].to_i.to_s(36)}"
      File.open(file, "w") { |f| f.write(backup.read)}
      # Décompression
      Zlib::GzipReader.open(file) { |gz| stream = gz.read }
      doc = REXML::Document.new(stream)
      # Suppression des données
      reflections = Company.reflections
      for name in reflections.keys.collect{|x| x.to_s}.sort
        reflection = reflections[name.to_sym]
        if reflection.macro==:has_many
          for x in company.send(name.to_sym)
            x.class.delete x.id
          end
        end
      end
      
      

      # Chargement des données sauvegardées
      
    end
  end
  

  def user
    @company = @current_company
    @user = @current_user
    @title = {:value=>@user.label}
  end

  dyta(:users, :conditions=>{:company_id=>['@current_company.id'],:deleted=>false}, :empty=>true) do |t| 
    t.column :name
    t.column :first_name
    t.column :last_name
    t.column :name, :through=>:role, :label=>tc(:role)
    t.column :free_price
    t.column :credits
    t.column :reduction_percent
    t.column :email
    t.column :admin
    t.action :locked, :actions=>{"true"=>{:action=>:users_unlock},"false"=>{:action=>:users_lock}}, :method=>:post
#    t.column :locked
#    t.action :users_lock , :image=>:unlock_access , :method=>:post , :confirm=>:sure
#    t.action :users_unlock , :image=>:lock_access , :method=>:post , :confirm=>:sure
    t.action :users_update, :image=>:update 
    t.action :users_delete, :image=>:delete , :method=>:post , :confirm=>:sure
    t.procedure :users_create, :action=>:users_create
  end

  def users
  end

  dyta(:establishments, :conditions=>{:company_id=>['@current_company.id']}, :empty=>true) do |t|
    t.column :name
    t.column :nic
    t.column :siret
    t.column :comment
    t.procedure :establishments_create, :action=>:establishments_create
    t.action :establishments_update, :image=>:update
    t.action :establishments_delete, :image=>:delete , :method=>:post , :confirm=>:sure
  end

  def establishments
  end
  
  dyta(:departments, :conditions=>{:company_id=>['@current_company.id']}, :empty=>true) do |t| 
    t.column :name
    t.column :comment
    t.procedure :departments_create, :action=>:departments_create
    t.action :departments_update, :image=>:update
    t.action :departments_delete, :image=>:delete , :method=>:post , :confirm=>:sure
  end
  dyta(:roles, :conditions=>{:company_id=>['@current_company.id']}) do |t| 
    t.column :name
    t.action :roles_update
  end


  def departments
  end

  def establishments_create
    access :establishments
    if request.post?
      @establishment = Establishment.new(params[:establishment])
      @establishment.company_id = @current_company.id
      redirect_to_back if @establishment.save
    else
      @establishment = Establishment.new
    end
    render_form
  end
 
  def establishments_update
    access :establishments
    @establishment = Establishment.find_by_id_and_company_id(params[:id], @current_company.id)
    if request.post? and @establishment
      if @establishment.update_attributes(params[:establishment])
        redirect_to_back
      end
    end
    render_form
  end

  def establishments_delete
    access :establishments
    if request.post? or request.delete?
      @establishment = Establishment.find_by_id_and_company_id(params[:id], @current_company.id)
      Establishment.delete(params[:id]) if @establishment
    end
    redirect_to_back
  end

  def departments_create
    access :departments
    if request.post? 
      @department = Department.new(params[:department])
      @department.company_id = @current_company.id
      redirect_to_back if @department.save
    else
      @department = Department.new
    end
    render_form
  end

  def departments_update
    access :departments
    @department = Department.find_by_id_and_company_id(params[:id] , @current_company.id)
    if request.post? and @department
      if @department.update_attributes(params[:department])
        redirect_to_back
      end
    end
    render_form
  end

  def departments_delete
    access :departments
    if request.post? or request.delete?
      @department= Department.find_by_id_and_company_id(params[:id] , @current_company.id)
      Department.delete(params[:id]) if @department
    end
    redirect_to_back
  end

  def roles_create
    @role = Role.new
    @rights = @current_company.find_all_rights(@@rights)
    if request.post?
      @role = Role.new(params[:role])
     # raise Exception.new params.inspect
      @role.company_id = @current_company.id
      @role.rights = "administrate_nothing "
      for right in params[:right]
        @role.rights += right[0].to_s+" "
      end
      #raise Exception.new   @role.rights.inspect
      redirect_to_back if @role.save
    end
  end

  def roles_update
    @role = find_and_check(:role, params[:id])
    session[:role] = @role
    @rights = @current_company.find_all_rights(@@rights)
    if request.post?
      @role.rights = "administrate_nothing "
      for right in params[:right]
        @role.rights += right[0].to_s+" "
      end
      redirect_to_back if @role.save
    end
  end
  
  def users_create
    access :users
    if request.xhr?
      @rights = session[:role_rights]
      session[:role] = find_and_check(:role, params[:user_role_id])
      render :action=>"check_rights.rjs"
    end
    if request.post? and not request.xhr?
    #  raise Exception.new params.inspect
      @user = User.new(params[:user])
      @user.company_id = @current_company.id
      @user.role_id = params[:user][:role_id]
      @user.rights = "administrate_nothing "
      for right in params[:right]
        @user.rights += right[0].to_s+" "
      end
      redirect_to_back if @user.save
    else
      @user = User.new
      @role = Role.find_by_name_and_company_id("Administrateur", @current_company.id)
      session[:role] = @role
      @rights = @current_company.find_all_rights(@@rights)
      session[:role_rights] = @rights
      #raise Exception.new @rights.inspect
    end
    render_form
  end

  def users_update
    access :users
    @user= User.find_by_id_and_company_id(params[:id], @current_company.id)
    if request.xhr?
      @rights = session[:role_rights]
      session[:role] = find_and_check(:role, params[:user_role_id])
      render :action=>"check_rights.rjs"
    end
    if request.post? and not request.xhr?
      if @user.update_attributes(params[:user]) 
        @user.rights = "administrate_nothing "
        for right in params[:right]
          @user.rights += right[0].to_s+" "
        end
        redirect_to_back if @user.save
      end
    else
      session[:role] = @user
      @role = Role.find_by_name_and_company_id("Administrateur", @current_company.id)
      @rights = @current_company.find_all_rights(@@rights)
      session[:role_rights] = @rights
    end
    render_form
  end
  
  def users_delete
    access :users
    if request.post? or request.delete?
      @user = User.find_by_id_and_company_id(params[:id], @current_company.id)
      if @user
        @user.deleted = true
        @user.save 
      end
    end
    redirect_to_back
  end
  
  def users_lock
    @user = User.find_by_id_and_company_id(params[:id], @current_company.id)
    if @user
      @user.locked = true
      @user.save
    end
    redirect_to_current
  end
  
  def users_unlock
    @user = User.find_by_id_and_company_id(params[:id], @current_company.id)
    if @user
      @user.locked = false
      @user.save
    end
    redirect_to_current
  end
  
end
