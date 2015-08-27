require 'spec_helper'

describe Consul::Lock do
  it 'has a version number' do
    expect(Consul::Lock::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end
