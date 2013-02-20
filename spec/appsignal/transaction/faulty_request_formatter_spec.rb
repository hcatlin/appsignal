require 'spec_helper'

describe Appsignal::TransactionFormatter::FaultyRequestFormatter do
  let(:parent) { Appsignal::TransactionFormatter }
  let(:transaction) { transaction_with_exception }
  let(:faulty) { parent::FaultyRequestFormatter.new(transaction) }
  subject { faulty }

  describe "#to_hash" do
    it "can call #to_hash on its superclass" do
      parent.new(transaction).respond_to?(:to_hash).should be_true
    end

    context "return value" do
      subject { faulty.to_hash }
      before { faulty.stub(:formatted_exception => :faulty_request) }

      it "includes the exception" do
        subject[:exception].should == :faulty_request
      end
    end
  end

  # protected

  it { should delegate(:backtrace).to(:exception) }
  it { should delegate(:name).to(:exception) }
  it { should delegate(:message).to(:exception) }

  describe "#formatted_exception" do
    subject { faulty.send(:formatted_exception) }

    its(:keys) { should include :backtrace }
    its(:keys) { should include :exception }
    its(:keys) { should include :message }
  end

  describe "#basic_process_action_event" do
    subject { faulty.send(:basic_process_action_event) }

    it "should return a hash with extra keys" do
      subject[:environment].should == {
        "HTTP_USER_AGENT" => "IE6",
        "SERVER_NAME" => "localhost"
      }
      subject[:session_data].should == {}
    end
  end
end
