require 'json'

run ->(env) {
  http_stuff = env.select{|k,v| k =~ /^[A-Z]/}
  json = JSON.dump(http_stuff)
  [200, {'Content-Lenght' => json.bytesize.to_s, 'Content-Type' => 'application/json'}, [json]]
}
