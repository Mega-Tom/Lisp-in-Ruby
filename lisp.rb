require 'test/unit'
include Test::Unit::Assertions

EMPTY = Object.new

class Token
    def initialize type, value
        @type = type
        @value = value
    end
    attr_reader :type, :value
    def self.make(str)
        if /^\d+$/ === str
            return Token.new :int, str.to_i
        else
            return Token.new :var, str
        end
    end
end

class Cons
    def initialize car, cdr
        @car = car
        @cdr = cdr
    end
    attr_reader :car, :cdr
    def self.make_list values
        if values.length == 0
            EMPTY
        else
            Cons.new(values.shift, Cons.make_list(values))
        end
    end
    def tail
        if @cdr.class == Cons
            "#{@car} #{@cdr.tail}"
        elsif @cdr==EMPTY
            "#{@car})"
        else
            "#{@car} . #{@cdr})"
        end
    end
    def to_s
        "(#{self.tail}"
    end
end

def parse code
    index = 0
    a = []
    while index < code.length
        token, index = get_token code, index
        a.push(token) if token
    end
    a
end

def get_token code, index
    index += 1 while /\s/ === code[index]
    
    case code[index]
    when /\w|[+\-*]/
        i = index
        i += 1 while /\w|[+\-*]/ === code[i]
        [Token.make(code[index ... i]), i]
    when '('
        list = []
        i = index + 1
        while true
            token,i = get_token(code, i)
            break if token.nil?
            list.push(token)
            raise "Unfinished list!" if i >= code.length
        end
        [Token.new(:list, list), i]
    when ')'
        return [nil, index+1]
    when '"'
        get_string code, index+1
    when nil
        return [nil,index]
    else
        raise "Unknow sym: #{code[index]} (in `#{code[index - 10...index + 10]}')"
    end
end

def get_string code, index
    i = index
    while i < code.length and code[i] != '"'
        i+=1
    end
    raise "unfinished string" if i == code.length
    [Token.new(:str, code[index ... i]), i+1]
end

def boolize thing
    case thing
    when String
        thing.length > 0
    when Integer
        thing != 0
    when EMPTY
        false
    else
        !!thing
    end
end

class Context
    def initialize parent=nil
        @vars = {}
        @funcs = {}
        @parent = parent
    end
    def [] var
        val = @vars[var]
        val = @parent[var] if @perent and not val
        raise "undefined variable #{var}" if val.nil?
        val
    end
    def []= var, val
        if @parent && !@vars.key?(var) and @parent.has_var?(var)
            @parent[var] = val
        else
            @vars[var] = val
        end
    end
    def set_local var, val
        @vars[var] = val
    end
    def has_var? var
        @vars.key?(var) || parent&.has_var?(var)
    end
    def defun tokens
        assert tokens[0].type == :var
        assert tokens[1].type == :list
        assert tokens[1].value.all?{|param| param.type == :var}
        @funcs[tokens[0].value] = tokens[1..-1]
    end
    def fun name
        @funcs[name] || (@parent&.fun(name))
    end
end

def execute tokens, context = Context.new
    ret = nil
    tokens.each do |t|
        ret = evaluate t, context
    end
    ret
end
def evaluate token, context
    if(token.type == :list)
        assert token.value[0].type == :var
        run_cmd(token.value[0].value, token.value[1..-1], context)
    elsif token.type == :str
        token.value
    elsif token.type == :var
        context[token.value]
    elsif token.type == :int
        token.value
    end
end
def run_cmd function, inputs, context
    fun = context.fun(function)
    if fun
        params = (inputs.map do |t|
            evaluate t, context
        end)
        assert params.length == fun[0].value.length
        inner_context = Context.new(context)
        params.length.times do |i|
            inner_context.set_local(fun[0].value[i].value, params[i])
        end
        return execute fun[1..-1], inner_context
    end
    case function
    when 'defun'
        context.defun(inputs)
    when 'write'
        puts(inputs.map do |t|
            evaluate t, context
        end)
    when '+'
        inputs.sum do |t|
            evaluate t, context
        end
    when '-'
        assert inputs.length == 2
        evaluate(inputs[0], context) - evaluate(inputs[1], context)
    when '*'
        (inputs.map do |t|
            evaluate t, context
        end).inject(:*)
    when 'set'
        assert inputs.length == 2
        assert inputs[0].type == :var
        context[inputs[0].value] = evaluate inputs[1], context
    when 'let'
        assert inputs.length >= 1
        assert inputs[0].type == :list
        inner_context = Context.new context
        inputs[0].value.each do |local|
            if local.type == :list
                assert local.value.length == 2
                assert local.value[0].type == :var
                inner_context.set_local(local.value[0].value, evaluate(local.value[1], context))
            end
        end
        execute inputs[1..-1], inner_context
    when 'cons'
        assert inputs.length == 2
        Cons.new(
            evaluate(inputs[0], context), 
            evaluate(inputs[1], context))
    when 'car'
        assert inputs.length == 1
        cell = evaluate(inputs[0], context)
        if cell.class == Cons
            cell.car
        else
            EMPTY
        end
    when 'cdr'
        assert inputs.length == 1
        evaluate(inputs[0], context).cdr
    when 'list'
        Cons.make_list(inputs.map do |t|
            evaluate t, context
        end)
    when 'if'
        assert inputs.length == 3
        cond = evaluate(inputs[0], context)
        if boolize(cond)
            evaluate(inputs[1], context)
        else
            evaluate(inputs[2], context)
        end
    when 'while'
        assert inputs.length > 1
        while boolize(evaluate(inputs[0], context))
            inputs[1..-1].each do |i|
                evaluate(i, context)
            end
        end
    when 'ordered'
        (inputs.map do |t|
            evaluate t, context
        end).each_cons(2).all? { |a, b| (a <=> b) <= 0 } ? 1 : 0
    when 'concat'
        (inputs.map do |t|
            evaluate(t, context).to_s
        end).sum('')
    else
        raise "function #{function} undefined"
    end
end

if ARGV.length == 0
    input = gets.chomp
else
    input = File.read(ARGV[0])
end
execute parse(input)