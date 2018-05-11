# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'coverage'
require 'active_support/core_ext/string/indent'
require 'active_support/core_ext/string/strip'

module DeepCover
  RSpec.describe Analyser::Ruby25LikeBranch do
    next if RUBY_VERSION < '2.5'
    Execution = Struct.new(:code, :ruby_result, :dc_result, :raw_dc_result)

    def run_dc_ruby25_like_branch(**args)
      covered_code = DeepCover::CoveredCode.new(**args)
      Tools.execute_sample(covered_code)
      DeepCover::Analyser::Ruby25LikeBranch.new(covered_code).results
    end

    # Mutations are applied automatically to the received code:
    #   A test will be made with and then without empty lines
    #   A test will be made with `if` replaced by `unless` (except if there is a elsif)
    #   A test will be made with `while` replaced by `until !(...)`
    #   A test will be made with every line containing only a number removed
    #   A test will be made with every line containing only a number with a second line before (DeepCover)
    #   Every mix of the above rules will be tested.
    matcher :have_similar_result_to_ruby do
      match do |ruby_code|
        @executions = []
        ruby_code = ruby_code.strip_heredoc
        ruby_codes = [ruby_code.rstrip]
        extra_ruby_codes = ruby_codes.map { |c| c.gsub(/^(\s*)(\d+\s*$)/, '') }
        extra_ruby_codes.concat(ruby_codes.map { |c| c.gsub(/^(\s*)(\d+\s*)$/, "\\1DeepCover\n\\1\\2") })
        ruby_codes.concat(extra_ruby_codes)
        ruby_codes.concat(ruby_codes.map { |c| c.gsub(/\bif\b/, 'unless') }) unless ruby_code[/\belsif\b/]
        ruby_codes.concat(ruby_codes.map { |c| c.gsub(/\bwhile(.*)\b/, 'until !(\1)') })

        ruby_codes += ruby_codes.map { |c| c.split("\n").select(&:present?).join("\n") }
        ruby_codes.uniq!

        ruby_codes.each(&method(:execute))

        @different_executions = @executions.reject { |e| e.ruby_result == e.dc_result }
        @non_uniq_index_executions = @executions.reject { |e| has_unique_index?(e.raw_dc_result) }

        @different_executions.empty? && @non_uniq_index_executions.empty?
      end

      failure_message do
        messages = (@different_executions + @non_uniq_index_executions).uniq.map do |execution|
          msg = []
          msg << 'For ruby code:'
          msg << execution.code.rstrip.indent(4)

          if @different_executions.include?(execution)
            msg << <<-MSG.strip_heredoc
              Expected something like:
                  #{execution.ruby_result.sort.to_h}
              but deep-dover generated something like:
                  #{execution.dc_result.sort.to_h}
            MSG
          end

          if @non_uniq_index_executions.include?(execution)
            msg << 'The index of the branches (first number) was not uniq, here is the raw output:'
            msg << "    #{execution.raw_dc_result}"
          end

          msg.join("\n")
        end

        messages.join("\n-----------\n")
      end

      def execute(ruby_code)
        f = Tempfile.new(['ruby', '.rb'])
        f.write(ruby_code)
        f.close

        ::Coverage.start(branches: true)
        Tools.execute_sample -> { require f.path }
        ruby_result = ::Coverage.result.values.first[:branches]
        $LOADED_FEATURES.delete(f.path)

        raw_dc_result = run_dc_ruby25_like_branch(source: ruby_code, path: f.path)

        ruby_result = normalize_result(ruby_result)
        dc_result = normalize_result(raw_dc_result)
        @executions << Execution.new(ruby_code, ruby_result, dc_result, raw_dc_result)
      end

      def normalize_result(result)
        result.map do |key, sub_hash|
          key = key.values_at(0, 2..-1)
          sub_hash = sub_hash.map do |sub_key, nb_hits|
            sub_key = sub_key.values_at(0, 2..-1)
            [sub_key, nb_hits]
          end.to_h
          [key, sub_hash]
        end.to_h
      end

      def has_unique_index?(result)
        indexes = result.flat_map do |key, sub_hash|
          [key[1]] + sub_hash.keys.map { |a| a[1] }
        end
        indexes == indexes.uniq
      end
    end

    # The list of cases to test, separated by ###
    # Mutations are applied to these test cases, see doc of the #have_similar_result_to_ruby matcher for details
    cases = <<-RUBY
      if DeepCover
        66
      end
    ###
      if DeepCover
        66
      elsif DeepCover::Node
        77
      end
    ###
      if DeepCover
        66
      elsif DeepCover::Node
        77
      elsif DeepCover::Analyser
        88
      end
    ###
      if DeepCover
        66
      else
        99
      end
    ###
      if DeepCover
        66
      elsif DeepCover::Node
        77
      else
        99
      end
    ###
      if DeepCover
        66
      elsif DeepCover::Node
        77
      elsif DeepCover::Analyser
        88
      else
        99
      end
    ###
      a = 123 if DeepCover
    ###
      DeepCover ? 1 : 0
    ###
      case DeepCover
      when 1
        11
      end
    ###
      case DeepCover
      when 1
        11
      when 2
        22
      end
    ###
      case DeepCover
      when 1
        11
      else
        33
      end
    ###
      case DeepCover
      when 1
        11
      when 2
        22
      else
        33
      end
    ###
      asd = 123
      asd&.to_i
    ###
      asd = nil
      asd&.to_i
    ###
      nil&.to_i&.to_i
    ###
      a = 1
      while a < 10
        a += 1
      end
    ###
      a = 1
      while a < 10
        DeepCover
        a += 1
      end
    ###
      a = 10
      while a < 10

      end
    ###
      a = 1
      a += 1 while a < 10
    ###
      a = 1
      begin
        a += 1
      end while a < 10
    ###
      a = 1
      begin
        DeepCover
        a += 1
      end while a < 10
    ###
      a = 10
      begin

      end while a < 10
    RUBY

    cases.split("###\n").each do |code|
      it { code.should have_similar_result_to_ruby }
    end

    it "`123 && 45` gives correct results for &&" do
      key, branches = run_dc_ruby25_like_branch(source: "123 && 45").first
      key[2..-1].should == [1, 0, 1, 9]

      then_branch, then_hits = branches.detect{|k, v| k.first == :then }
      then_hits.should == 1
      then_branch[2..-1].should == [1, 7, 1, 9]

      else_branch, else_hits = branches.detect{|k, v| k.first == :else }
      else_hits.should == 0
      else_branch[2..-1].should == [1, 0, 1, 9]
    end

    it "`false && 45` gives correct results for &&" do
      key, branches = run_dc_ruby25_like_branch(source: "false && 45").first
      key[2..-1].should == [1, 0, 1, 11]

      then_branch, then_hits = branches.detect{|k, v| k.first == :then }
      then_hits.should == 0
      then_branch[2..-1].should == [1, 9, 1, 11]

      else_branch, else_hits = branches.detect{|k, v| k.first == :else }
      else_hits.should == 1
      else_branch[2..-1].should == [1, 0, 1, 11]
    end

    it "`123 || 45` gives correct results for ||" do
      key, branches = run_dc_ruby25_like_branch(source: "123 || 45").first
      key[2..-1].should == [1, 0, 1, 9]

      then_branch, then_hits = branches.detect{|k, v| k.first == :then }
      then_hits.should == 1
      then_branch[2..-1].should == [1, 0, 1, 9]

      else_branch, else_hits = branches.detect{|k, v| k.first == :else }
      else_hits.should == 0
      else_branch[2..-1].should == [1, 7, 1, 9]
    end

    it "`false || 45` gives correct results for ||" do
      key, branches = run_dc_ruby25_like_branch(source: "false || 45").first
      key[2..-1].should == [1, 0, 1, 11]

      then_branch, then_hits = branches.detect{|k, v| k.first == :then }
      then_hits.should == 0
      then_branch[2..-1].should == [1, 0, 1, 11]

      else_branch, else_hits = branches.detect{|k, v| k.first == :else }
      else_hits.should == 1
      else_branch[2..-1].should == [1, 9, 1, 11]
    end
  end
end