# Copyright (c) Cognitect, Inc.
# All rights reserved.

require 'spec_helper'

module Transit
  describe RollingCache do
    describe 'writing' do
      it 'returns the value the first time it sees it' do
        assert { RollingCache.new.write('abcd') == 'abcd' }
      end

      it 'returns a key the 2nd thru n times it sees a value' do
        rc = RollingCache.new
        assert { rc.write('abcd') == 'abcd' }

        key = rc.write('abcd')
        assert { key != 'abcd' }

        100.times do
          assert { rc.write('abcd') == key }
        end
      end

      it 'has a default CACHE_SIZE of 94' do
        assert { RollingCache::CACHE_SIZE == 94**2 }
      end

      it 'can handle CACHE_SIZE different values' do
        rc = RollingCache.new
        RollingCache::CACHE_SIZE.times do |i|
          assert { rc.write("value#{i}") == "value#{i}" }
        end

        assert { rc.size == RollingCache::CACHE_SIZE }
      end

      it 'resets after CACHE_SIZE different values' do
        rc = RollingCache.new
        (RollingCache::CACHE_SIZE+1).times do |i|
          assert{ rc.write("value#{i}") == "value#{i}" }
        end

        assert { rc.size == 1 }
      end
    end

    describe ".cacheable?" do
      it 'returns false for small strings' do
        cache = RollingCache.new

        names = random_strings(3, 500)
        1000.times do |i|
          name = names.sample
          assert { !cache.cacheable?(name, false) }
          assert { !cache.cacheable?(name, true)  }
        end
      end

      it 'returns false for non map-keys' do
        cache = RollingCache.new

        names = random_strings(200, 500)
        1000.times do |i|
          name = names.sample
          assert { !cache.cacheable?(name, false) }
        end
      end
    end

    describe ".cache_key?" do
      it 'special cases map-as-array key as false' do
        cache = RollingCache.new
        assert { !cache.cache_key?(Transit::MAP_AS_ARRAY) }
      end
    end

    describe 'reading' do
      it 'returns the value, given a key that has a value in the cache' do
        rc = RollingCache.new
        rc.write 'abcd'
        key = rc.write 'abcd'
        assert { rc.read(key) == 'abcd' }
      end
    end
  end
end
