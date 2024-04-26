require 'test/unit'
include Test::Unit::Assertions

EMPTY = Object.new
LITERAL_RE = /\w|[+\-*]/

class Token
    def initialize type, value=nil
        @type = type
        @value = value
    end
    def inspect
        if @value
            "#{@type}: #{@value}"
        else
            "#{@type}"
        end
    end

    attr_reader :type, :value
end

def tokenize code
    line = 1
    mode = :start
    str = ""
    tokens = []
    code.each_char do |c|
        line += 1 if c == '\n'
        if mode == :literal
            if LITERAL_RE === c
                str += c
            else
                tokens.push Token.new(:literal, str)
                mode = :start
            end
        end
        if mode == :string_escape
            str += c # TODO add '\n' etc.
            mode = :string
        elsif mode == :string
            if '"' == c
                tokens.push Token.new(:string, str)
                mode = :start
                next
            elsif '\\' == c
                mode = :string_escape
            else
                str += c
            end
        end
        if mode == :start
            case c
            when '('
                tokens.push Token.new(:open)
            when ')'
                tokens.push Token.new(:close)
            when LITERAL_RE
                str = c
                mode = :literal
            when '"'
                str = ''
                mode = :string
            when /\s/
                mode = :start
            else
                raise "Unexpected char `#{c}' (line #{line})"
            end
        end
    end
    tokens
end

class Node
    def initialize type, value
        @type = type
        @value = value
    end
    attr_reader :type, :value
    def self.make(str)
        if /^\d+$/ === str
            return Node.new :int, str.to_i
        else
            return Node.new :var, str
        end
    end
end
def parse tokens
    index = 0
    a = []
    while index < tokens.length
        node, index = get_node tokens, index
        a.push(node) if node
    end
    a
end

def get_node tokens, index
    return [nil, index] if tokens[index].nil?
    case tokens[index].type
    when :literal
        [Node.make(tokens[index].value), index + 1]
    when :open
        list = []
        i = index + 1
        while true
            node, i = get_node(tokens, i)
            break if node.nil?
            list.push(node)
            raise "Unfinished list!" if i >= tokens.length
        end
        [Node.new(:list, list), i]
    when :close
        [nil, index+1]
    when :string
        [Node.new(:str, tokens[index].value), index+1]
    else
        raise "Unknow token: #{token[index]}"
    end
end

def get_string code, index
    i = index
    while i < code.length and code[i] != '"'
        i+=1
    end
    raise "unfinished string" if i == code.length
    [Node.new(:str, code[index ... i]), i+1]
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
    def defun nodes
        assert nodes[0].type == :var
        assert nodes[1].type == :list
        assert nodes[1].value.all?{|param| param.type == :var}
        @funcs[nodes[0].value] = nodes[1..-1]
    end
    def fun name
        @funcs[name] || (@parent&.fun(name))
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

def execute nodes, context = Context.new
    ret = nil
    nodes.each do |t|
        ret = evaluate t, context
    end
    ret
end
def evaluate node, context
    if(node.type == :list)
        assert node.value[0].type == :var
        run_cmd(node.value[0].value, node.value[1..-1], context)
    elsif node.type == :str
        node.value
    elsif node.type == :var
        context[node.value]
    elsif node.type == :int
        node.value
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
execute parse(p tokenize(input))