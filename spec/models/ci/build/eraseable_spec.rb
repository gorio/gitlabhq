require 'spec_helper'

describe Ci::Build::Eraseable, models: true do
  shared_examples 'eraseable' do
    it 'should remove artifact file' do
      expect(build.artifacts_file.exists?).to be_falsy
    end

    it 'should remove artifact metadata file' do
      expect(build.artifacts_metadata.exists?).to be_falsy
    end

    it 'should erase build trace in trace file' do
      expect(File.zero?(build.path_to_trace)).to eq true
    end

    it 'should set erased to true' do
      expect(build.erased?).to be true
    end

    it 'should set erase date' do
      expect(build.erased_at).to_not be_falsy
    end
  end

  context 'build is not eraseable' do
    let!(:build) { create(:ci_build) }

    describe '#erase!' do
      it { expect { build.erase! }.to raise_error(StandardError, /Build not eraseable!/ )}
    end

    describe '#eraseable?' do
      subject { build.eraseable? }
      it { is_expected.to eq false }
    end

    describe '#erase_url' do
      subject { build.erase_url }
      it { is_expected.to be_falsy }
    end
  end

  context 'build is eraseable' do
    let!(:build) { create(:ci_build_with_trace, :success, :artifacts) }

    describe '#erase!' do
      before { build.erase!(erased_by: user) }

      context 'erased by user' do
        let!(:user) { create(:user, username: 'eraser') }

        include_examples 'eraseable'

        it 'should record user who erased a build' do
          expect(build.erased_by).to eq user
        end
      end

      context 'erased by system' do
        let(:user) { nil }

        include_examples 'eraseable'

        it 'should not set user who erased a build' do
          expect(build.erased_by).to be_nil
        end
      end
    end

    describe '#eraseable?' do
      subject { build.eraseable? }
      it { is_expected.to eq true }
    end

    describe '#erase_url' do
      subject { build.erase_url }
      it { is_expected.to be_truthy }
    end

    context 'metadata and build trace are not available' do
      let!(:build) { create(:ci_build, :success, :artifacts) }
      before { build.remove_artifacts_metadata! }

      describe '#erase!' do
        it 'should not raise error' do
          expect { build.erase! }.to_not raise_error
        end
      end
    end
  end
end
