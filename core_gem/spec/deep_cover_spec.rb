# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe DeepCover do
  describe 'cover' do
    after { DeepCover.reset }
    it 'temporarily overrides (or not in 2.3 +) `require`, `require_relative` and `autoload`' do
      methods = %i[require require_relative]
      methods << :autoload unless RUBY_PLATFORM == 'java'
      original = methods.map { |m| method(m).source_location }
      2.times do
        sources = nil
        DeepCover.cover do
          sources = methods.map { |m| method(m).source_location }
        end
        sources.zip(original).each do |now, before|
          if RUBY_VERSION < '2.3.0' || RUBY_PLATFORM == 'java'
            now.should_not == before
          else
            # We use load_iseq in 2.3+, so no override in that case
            now.should == before
          end
        end
        methods.map { |m| method(m).source_location }.should == original
      end
    end

    it "doesn't choke on libs with encoding snafus" do
      DeepCover.cover paths: '/' do
        expect do
          require('rexml/source').should == true
        end.to output(%r[Can't cover .*rexml/source.rb because of incompatible encoding]).to_stderr
      end
      REXML::SourceFactory.should be_instance_of(Class)
    end
  end
end
