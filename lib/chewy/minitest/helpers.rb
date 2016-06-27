require_relative 'search_index_receiver'

module Chewy
  module Minitest
    module Helpers
      extend ActiveSupport::Concern

      # Assert that an index *changes* during a block.
      # @param (Chewy::Type) index the index / type to watch, eg EntitiesIndex::Entity.
      # @param (Symbol) strategy the Chewy strategy to use around the block. See Chewy docs.
      # @param (boolean) assert the index changes
      # @param (boolean) bypass_actual_index
      #   True to preempt the http call to Elastic, false otherwise.
      #   Should be set to true unless actually testing search functionality.
      #
      # @return (SearchIndexReceiver) for optional further assertions on the nature of the index changes.
      def assert_indexes index, strategy: :atomic, bypass_actual_index: true, &test_actions
        type = Chewy.derive_type index
        receiver = SearchIndexReceiver.new

        bulk_method = type.method :bulk
        # Manually mocking #bulk because we need to properly capture `self`
        bulk_mock = -> (*bulk_args) do
          receiver.catch bulk_args, self

          unless bypass_actual_index
            bulk_method.call *bulk_args
          end

          {}
        end

        type.define_singleton_method :bulk, bulk_mock

          Chewy.strategy(strategy) do
            test_actions.call
          end

        type.define_singleton_method :bulk, bulk_method

        assert_includes receiver.updated_indexes, index, "Expected #{index} to be updated but it wasn't"

        receiver
      end

      # Run indexing for the database changes during the block provided.
      # By default, indexing is run at the end of the block.
      # @param (Symbol) strategy the Chewy index update strategy see Chewy docs.
      def run_indexing strategy: :atomic
        Chewy.strategy strategy do
          yield
        end
      end

      class_methods do
        # Declare that all tests in this file require real indexing, always.
        # In my completely unscientific experiments, this roughly doubled test runtime.
        # Use with trepidation.
        def index_everything!
          setup do
            Chewy.strategy :urgent
          end

          teardown do
            Chewy.strategy.pop
          end
        end
      end

      included do
        teardown do
          # always destroy indexes between tests
          # Prevent croll pollution of test cases due to indexing
          Chewy.massacre
        end
      end

    end
  end
end
