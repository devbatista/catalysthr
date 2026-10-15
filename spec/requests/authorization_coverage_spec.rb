require "rails_helper"

# Spec 03, RN-03-003 (P-03-10): every controller action authorizes.
RSpec.describe "Authorization coverage" do
  it "finds no routed action without authorization" do
    expect(AuthorizationCoverage.missing).to be_empty
  end

  describe "a new action (CA-03-008)" do
    before(:all) do
      Object.const_set("CoverageProbeController", Class.new(ApplicationController) {
        def unguarded
        end

        def guarded
          authorize! :read, :probe
        end

        def opened
        end
        public_actions :opened
      })
    end

    after(:all) { Object.send(:remove_const, :CoverageProbeController) }

    let(:routes) do
      ActionDispatch::Routing::RouteSet.new.tap do |set|
        set.draw do
          get "unguarded", to: "coverage_probe#unguarded"
          get "guarded", to: "coverage_probe#guarded"
          get "opened", to: "coverage_probe#opened"
        end
      end
    end

    it "fails the coverage check when the action does not call authorize!" do
      expect(AuthorizationCoverage.missing(routes.routes)).to eq([ "coverage_probe#unguarded" ])
    end
  end
end
