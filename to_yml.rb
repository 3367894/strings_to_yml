require 'yaml'
require 'russian'
require 'haml'
require 'action_view'

def set_by_keys(data, keys, value, index)
  key = keys.first
  if key.nil?
    # return value
    key = "key_#{index}"
    data[key] = value
  else
    key = key[1..-1] if key[0] == '_'
    data[key] = if data.key?(key)
                  set_by_keys(data[key], keys[1..-1], value, index)
                else
                  set_by_keys({}, keys[1..-1], value, index)
                end
  end
  data
end

def remove_extname(path)
  while (ext = File.extname(path)).length > 0
    path = path[0..-ext.length - 1]
  end
  path
end

def get_strings(text)
  current = nil
  list = %w(' ")
  data = ''
  strings = []
  text.chars.each do |ch|
    if list.include?(ch)
      if current.nil?
        current = ch
        next
      elsif current == ch
        strings << data
        data = ''
        current = nil
        next
      end
    end
    data << ch unless current.nil?
  end
  strings
end


data = {}
index = 1
app_path = '/home/kirill/projects/mst/valkyrie/app'
texts_path = File.expand_path(File.dirname(__FILE__) + '/texts.txt')

`find #{app_path} -type f -exec grep -HnR '[а-яА-я]' {} \\; > #{texts_path}`

c_index = 0

File.open(texts_path).each do |line|
  next if line =~ /^Binary file/

  line.sub!(app_path, '.')
  match = /\.\/(.*):(\d+):(.*)/.match(line)
  path = match[1].strip
  extname = File.extname(path)
  norm_path = remove_extname(path)
  pathes = norm_path.split('/')
  line_number = match[2].strip
  text = match[3].strip
  text.gsub!('#{', '%{')

  next if text[0] == '#' || text[0..1] == '-#' || (text[0] == '*' && extname == '.js') || text[0..1] == '//'

  found = 0
  get_strings(text).each do |str|
    next if str == Russian.transliterate(str)
    found += 1
    index += 1
    set_by_keys(data, pathes, str, index)
  end

  if found == 0
    if text != Russian.transliterate(text)
      if text =~ /[A-Za-z]/
        if extname == '.haml' || extname == '.hamlc'
          begin
            engine = Haml::Engine.new(text)
            html = engine.render
            text = ActionView::Base.full_sanitizer.sanitize(html)
            index += 1
            set_by_keys(data, pathes, text, index)
          rescue NameError, Haml::SyntaxError
            puts line
            c_index += 1
          end
        else
          c_index += 1
          puts line
        end
      else
        index += 1
        set_by_keys(data, pathes, text, index)
      end
    end
  end
end

puts index
puts c_index
File.write('/tmp/ru.yml', { ru: data }.to_yaml)

