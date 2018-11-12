require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, "very, very, secret"
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/public/files", __FILE__)
  else
    File.expand_path("../public/files", __FILE__)
  end
end

before do
  session[:albums] ||= []
end

  def find_album(album_name)
   album = session[:albums].find { |album| album[:name] == album_name }
  end

helpers do

  def find_cover(album_name)
    album = session[:albums].find { |album| album[:name] == album_name }
    album[:photos][0]
  end

  def remove_ext(filename)
    File.basename(filename, ".*")
  end
end

def error_for_album_name(name)
  if !(1..20).cover?(name.size)
    "Album must be between 1 and 20 characters."
  elsif session[:albums].any? {|album| album[:name] == name}
    "Album name must be unique."
  end
end

def filetype_error(name)
  if ![".jpg", "jpeg", ".gif", ".png"].include?(File.extname(name))
    "File must be .jpg, .gif, or .png"
  end
end

get "/" do
  @albums = session[:albums]

  @files = Dir.glob("public/files/*").map do |filename|
    File.basename(filename)
  end.sort
  erb :index

end

get "/:album/upload" do
  @album = params[:album]
  erb :upload
end

post "/:album/upload" do
  @albums = session[:albums]
  @album = params[:album]
  
  if params[:file]
    filename = params[:file][:filename]
    tempfile = params[:file][:tempfile]
    if filetype_error(filename)
      session[:message] = filetype_error(filename)
      erb :upload
    else
      target = "public/files/#{filename}"
      File.open(target, 'wb') {|f| f.write tempfile.read }

      @album = find_album(params[:album])

      @album[:photos] << filename
      session[:message] = "A photo has been added to #{params[:album]}"
      redirect "/#{params[:album]}"
    end
  end
end

post "/albums" do
  @albums = session[:albums]
  error = error_for_album_name(params[:album_name])
  if error
    session[:album_name_error] = error
    erb :index
  else
    album_name = params[:album_name]

    session[:albums] << {name: album_name, photos: []}
    session[:message] = "A new album has been created"

    redirect "/"
  end
end

def find_album(album_name)
  album = session[:albums].find { |album| album[:name] == album_name }
end

def find_photo(photo_name, album)
  album[:photos].find { |photo| File.basename(photo) == photo_name }
end

get "/photo/:filename" do 
  @filename = params[:filename]
  erb :photo
end

get "/photos" do
  @files = Dir.glob("public/files/*").map do |filename|
    File.basename(filename)
  end.sort

  erb :all_photos
end

get "/:album_name" do
  @album_name = params[:album_name]
  @album = find_album(@album_name)
  @photos = @album[:photos]

  erb :album
end

post "/:album_name/destroy" do
  @album_name = params[:album_name]
  album = find_album(@album_name)
  album[:photos].each do |photo|
    File.delete(File.join(data_path, photo)) 
  end
  session[:albums].delete(album)

  session[:message] = "Album has been deleted"

  redirect "/"
end

get "/:album_name/rename" do
  @album_name = params[:album_name]

  erb :rename
end


post "/:album_name/rename" do
  @album_name = params[:album_name]
  error = error_for_album_name(params[:new_album_name])
  if error
    session[:message] = error
    erb :rename
  else
    @album_name = params[:album_name]
    @albums = session[:albums]
    find_album(@album_name)[:name] = params[:new_album_name]

    session[:message] = "Album has been renamed"

    redirect "/"
  end
end

# display single photo
get "/albums/:filename" do

  @filename = params[:filename]
  erb :photo
end

get "/:album_name/:filename/edit" do
  @album_name = params[:album_name]
  @filename = params[:filename]
  erb :edit_photo
end

post "/:album_name/:filename/delete" do
  @album_name = params[:album_name]
  @filename = params[:filename]
  File.delete(File.join(data_path, @filename))
  album = find_album(@album_name)
  photo = find_photo(@filename, album)
  album[:photos].delete(photo)

  session[:message] = "#{@filename} was deleted."

  redirect "/#{@album_name}"
end

post "/:album_name/:filename/rename" do
  @album_name = params[:album_name]
  @filename = params[:filename]
  @new_filename = params[:new_filename]
  album = find_album(@album_name)
  
  File.rename(File.join(data_path, @filename), File.join(data_path, @new_filename))
  album[:photos].delete(@filename)
  album[:photos] << @new_filename

  session[:message] = "#{@filename} was renamed."
  redirect "/#{@album_name}"
end

