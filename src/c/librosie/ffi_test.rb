# gem install ffi

require 'ffi'
require 'json'

class AP < FFI::AutoPointer
  def self.release(p)
    Libc.free(p) unless p.null?
  end
end

module Libc
  extend FFI::Library
  ffi_lib FFI::Library::LIBC
  attach_function 'puts', [ :string ], :int
  attach_function 'strlcpy', [ :pointer, :string, :size_t ], :pointer
  attach_function :malloc, [:size_t], AP
  attach_function :free, [ AP ], :void
end

print Libc.puts("Hello, World!"), "\n"

buffer = Libc.malloc("a".size() * 100)              # Max size of return string
retptr = Libc.strlcpy(buffer, "Abcdef", 100)
print (buffer.null? ? "<null string>" : buffer.read_string()), "\n"


class CString < FFI::Struct
  layout :len, :uint32,
         :ptr, :pointer
end

def CString_from_string(str)
  instance = CString.new
  instance[:len] = str.length
  instance[:ptr] = FFI::MemoryPointer.from_string(str)
  print "INIT FROM STRING: ", str, " whose length is: ", str.length, "\n"
  instance
end

module Rosie
  extend FFI::Library
  ffi_convention :stdcall
  ffi_lib_flags :now                                # required so other shared objects can resolve names
  ffi_lib "./librosie.so"
  attach_function 'initialize', [ :string ], :void
  # attach_function 'rosie_api', [ :string, CString.val, CString.val ], :int
  # attach_function 'new_engine', [ :pointer, CString.val ], :int
  attach_function 'rosie_api', [ :string, CString, CString ], CString.val
  attach_function 'new_engine', [ CString ], CString.val
  attach_function 'free_string', [ CString.val ], :void
  attach_function 'testbyvalue', [ CString.val ], :uint32
  attach_function 'testbyref', [ :pointer ], :uint32
  attach_function 'testretstring', [ CString ], CString.val
end

Rosie.initialize("asldkasldk")

config_string = CString_from_string("{\"name\":\"Ruby engine\"}")

print "config_string string: ", config_string[:ptr].read_string_length(config_string[:len]), "\n"
print "config_string length: ", config_string[:len], "\n"
print "config_string struct size: ", CString.size, "\n"

ignored = CString_from_string("ignored")

foo2 = Rosie.testbyref(ignored.pointer)
foo1 = Rosie.testbyvalue(ignored)

maybe_CString = Rosie.testretstring(ignored.pointer)
print "RETURNED CString len is: ", maybe_CString[:len], "; value is: ", maybe_CString[:ptr].read_string, "\n"
#Rosie.free_string(maybe_CString)

eid_retval = Rosie.new_engine(config_string.pointer)
print "LEN result of api call is: ", eid_retval[:len], "\n"
#retval_js = eid_retval[:ptr].read_string_length(eid_retval[:len])
retval_js = eid_retval[:ptr].read_string
print "STRING result of api call is: ", retval_js, "\n"
#Rosie.free_string(eid_retval)

retval = JSON.parse(retval_js)
# print retval_js, "\n"
# print retval[0], "\n"
eid_string = CString.new
eid_string[:ptr] = FFI::MemoryPointer.from_string(retval[1])
eid_string[:len] = retval[1].length
print "eid_string value is: ", eid_string[:ptr].read_string_length(eid_string[:len]), "; eid_string len is: ", eid_string[:len], "\n"

config = {'expression' => "\"ign\"", 'encode' => false} 
config_js = JSON.generate(config)
print "config_js is: ", config_js, "\n"

#Rosie.free_string(config_string)
config_string[:ptr] = FFI::MemoryPointer.from_string(config_js)
config_string[:len] = config_js.length

retval = Rosie.rosie_api("configure_engine", eid_string, config_string)
print retval[:ptr].read_string, "\n"
#Rosie.free_string(retval)
retval = Rosie.rosie_api("inspect_engine", eid_string, ignored)
print retval[:ptr].read_string, "\n"
#Rosie.free_string(retval)
retval = Rosie.rosie_api("match", eid_string, ignored)
print retval[:ptr].read_string, "\n"
retval = Rosie.rosie_api("match", eid_string, config_string)
print retval[:ptr].read_string, "\n"
#Rosie.free_string(retval)

actual_string = "This is NOT valid json"
config_string[:ptr] = FFI::MemoryPointer.from_string(actual_string)
config_string[:len] = actual_string.length
retval = Rosie.new_engine(config_string.pointer)
print retval[:ptr].read_string, "\n"
#Rosie.free_string(retval)

retval = Rosie.rosie_api("load_manifest", eid_string, config_string)
print retval[:ptr].read_string, "\n"
#Rosie.free_string(retval)

retval = Rosie.rosie_api("configure_engine", eid_string, config_string)
print retval[:ptr].read_string, "\n"
#Rosie.free_string(retval)

# Loop test prep

test = CString_from_string("$sys/MANIFEST")
print "TEST: len=", test[:len], "\n"
print "TEST: string=", test[:ptr].read_string, "\n"

retval = Rosie.rosie_api("load_manifest", eid_string, test)

config = {'expression' => "[:digit:]+", 'encode' => false} 
config_js = JSON.generate(config)
print "config_js is: ", config_js, "\n"

config_string[:ptr] = FFI::MemoryPointer.from_string config_js 
config_string[:len] = config_js.length
retval = Rosie.rosie_api("configure_engine", eid_string, config_string)
print retval[:ptr].read_string, "\n"

# Loop test

foo = CString.new
foo[:ptr] = FFI::MemoryPointer.from_string "123"
foo[:len] = 3

for i in 0..10000000 do
  retval = Rosie.rosie_api "match", eid_string, foo
  string_to_return_to_caller = retval[:ptr].read_string_length(retval[:len])
  Rosie.free_string(retval)
#  print "Match: ", retval[:ptr].read_string, "\n"
end


