require 'spec_helper'
require 'travis/build/assertions'
require 'support/mocks'
require 'support/matchers'

describe Job::Runner do
  let(:job)      { stub('job:configure', :run => { :foo => 'foo' }) }
  let(:runner)   { Job::Runner.new(job) }
  let(:observer) { Mocks::Observer.new }

  attr_reader :now

  before :each do
    @now = Time.now
    Time.stubs(:now).returns(@now)

    runner.observers << observer
  end

  it 'implements a simple observer pattern' do
    runner.send(:notify, :start, nil, :data)
    runner.send(:notify, :log, nil, :data)
    runner.send(:notify, :finish, nil, :data)
    observer.events.map { |event| event.type }.should == [:start, :log, :finish]
  end

  describe 'run' do
    it 'notifies observers about the :start event' do
      runner.run
      observer.events.should include_event(:start, job, :started_at => now)
    end

    it 'runs the job' do
      job.expects(:run)
      runner.run
    end

    describe 'with no exception happening' do
      it 'notifies observers about the :finish event' do
        runner.run
        observer.events.should include_event(:finish, job, :result => { :foo => 'foo' }, :finished_at => now)
      end
    end

    describe 'with an exception being raised in the job' do
      it 'logs the exception' do
        job.stubs(:run).raises(AssertionFailed.new(job, 'install'))
        runner.run
        observer.events.should include_event(:log, job, :output => /Error: .*: install/)
      end

      it 'still notifies observers about the :finish event' do
        runner.run
        observer.events.should include_event(:finish, job, :result => { :foo => 'foo' }, :finished_at => now)
      end
    end
  end
end