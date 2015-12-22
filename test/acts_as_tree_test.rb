require 'minitest/autorun'
require 'minitest/benchmark'
require 'active_record'
require 'acts_as_tree'

class MiniTest::Unit::TestCase
  def assert_queries(num = 1, &block)
    query_count, result = count_queries(&block)
    result
  ensure
    assert_equal num, query_count, "#{query_count} instead of #{num} queries were executed."
  end

  def assert_no_queries(&block)
    assert_queries(0, &block)
  end

  def count_queries &block
    count = 0

    counter_f = ->(name, started, finished, unique_id, payload) {
      unless %w[ CACHE SCHEMA ].include? payload[:name]
        count += 1
      end
    }

    begin
      subscribed = ActiveSupport::Notifications.subscribe("sql.active_record", &counter_f)
      result = block.call
    ensure
      ActiveSupport::Notifications.unsubscribe subscribed
    end

    [count, result]
  end

  def capture_stdout(&block)
    real_stdout = $stdout

    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = real_stdout
  end
end

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

def setup_db(counter_cache = false)
  # AR keeps printing annoying schema statements
  capture_stdout do
    ActiveRecord::Base.logger
    ActiveRecord::Schema.define(version: 1) do
      create_table :mixins do |t|
        t.column :type, :string
        t.column :parent_id, :integer
        t.column(:children_count, :integer, default: 0) if counter_cache
        t.timestamps null: false
      end
    end

    Mixin.reset_column_information
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Mixin < ActiveRecord::Base
  include ActsAsTree
end

class TreeMixin < Mixin
  acts_as_tree foreign_key: "parent_id", order: "id"
end

class TreeMixinWithoutOrder < Mixin
  acts_as_tree foreign_key: "parent_id"
end

class TreeMixinNullify < Mixin
  acts_as_tree foreign_key: "parent_id", order: "id", dependent: :nullify
end

class TreeMixinWithCounterCache < Mixin
  acts_as_tree foreign_key: "parent_id", order: "id", counter_cache: :children_count
end

class RecursivelyCascadedTreeMixin < Mixin
  acts_as_tree foreign_key: "parent_id"
  has_one :first_child, class_name: 'RecursivelyCascadedTreeMixin', foreign_key: :parent_id
end

class TreeMixinWithTouch < Mixin
   acts_as_tree foreign_key: "parent_id", order: "id", touch: true
end

class TreeTest < MiniTest::Unit::TestCase

  def setup
    setup_db

    @root1              = TreeMixin.create!
    @root_child1        = TreeMixin.create! parent_id: @root1.id
    @child1_child       = TreeMixin.create! parent_id: @root_child1.id
    @child1_child_child = TreeMixin.create! parent_id: @child1_child.id
    @root_child2        = TreeMixin.create! parent_id: @root1.id
    @root2              = TreeMixin.create!
    @root3              = TreeMixin.create!
  end

  def teardown
    teardown_db
  end

  def test_children
    assert_equal @root1.children, [@root_child1, @root_child2]
    assert_equal @root_child1.children, [@child1_child]
    assert_equal @child1_child.children, [@child1_child_child]
    assert_equal @child1_child_child.children, []
    assert_equal @root_child2.children, []
  end

  def test_parent
    assert_equal @root_child1.parent, @root1
    assert_equal @root_child1.parent, @root_child2.parent
    assert_nil @root1.parent
  end

  def test_delete
    assert_equal 7, TreeMixin.count
    @root1.destroy
    assert_equal 2, TreeMixin.count
    @root2.destroy
    @root3.destroy
    assert_equal 0, TreeMixin.count
  end

  def test_insert
    @extra = @root1.children.create

    assert @extra

    assert_equal @extra.parent, @root1

    assert_equal 3, @root1.reload.children.count
    assert @root1.children.include?(@extra)
    assert @root1.children.include?(@root_child1)
    assert @root1.children.include?(@root_child2)
  end

  def test_ancestors
    assert_equal [], @root1.ancestors
    assert_equal [@root1], @root_child1.ancestors
    assert_equal [@root_child1, @root1], @child1_child.ancestors
    assert_equal [@root1], @root_child2.ancestors
    assert_equal [], @root2.ancestors
    assert_equal [], @root3.ancestors
  end

  def test_root
    assert_equal @root1, TreeMixin.root
    assert_equal @root1, @root1.root
    assert_equal @root1, @root_child1.root
    assert_equal @root1, @child1_child.root
    assert_equal @root1, @root_child2.root
    assert_equal @root2, @root2.root
    assert_equal @root3, @root3.root
  end

  def test_roots
    assert_equal [@root1, @root2, @root3], TreeMixin.roots
  end

  def test_leaves
    assert_equal [@child1_child_child, @root_child2, @root2, @root3], TreeMixin.leaves
  end

  def test_default_tree_order
    assert_equal [@root1, @root_child1, @child1_child, @child1_child_child, @root_child2, @root2, @root3], TreeMixin.default_tree_order
  end

  def test_siblings
    assert_equal [@root2, @root3], @root1.siblings
    assert_equal [@root_child2], @root_child1.siblings
    assert_equal [], @child1_child.siblings
    assert_equal [@root_child1], @root_child2.siblings
    assert_equal [@root1, @root3], @root2.siblings
    assert_equal [@root1, @root2], @root3.siblings
  end

  def test_self_and_siblings
    assert_equal [@root1, @root2, @root3], @root1.self_and_siblings
    assert_equal [@root_child1, @root_child2], @root_child1.self_and_siblings
    assert_equal [@child1_child], @child1_child.self_and_siblings
    assert_equal [@root_child1, @root_child2], @root_child2.self_and_siblings
    assert_equal [@root1, @root2, @root3], @root2.self_and_siblings
    assert_equal [@root1, @root2, @root3], @root3.self_and_siblings
  end

  def test_self_and_children
    assert_equal [@root1, @root_child1, @root_child2], @root1.self_and_children
    assert_equal [@root2], @root2.self_and_children
  end

  def test_self_and_ancestors
    assert_equal [@child1_child, @root_child1, @root1], @child1_child.self_and_ancestors
    assert_equal [@root2], @root2.self_and_ancestors
  end

  def test_self_and_descendants
    assert_equal [@root1, @root_child1, @root_child2, @child1_child, @child1_child_child], @root1.self_and_descendants
    assert_equal [@root2], @root2.self_and_descendants
  end

  def test_descendants
    assert_equal [@root_child1, @root_child2, @child1_child, @child1_child_child], @root1.descendants
    assert_equal [], @root2.descendants
  end

  def test_nullify
    root4       = TreeMixinNullify.create!
    root4_child = TreeMixinNullify.create! parent_id: root4.id

    assert_equal 2, TreeMixinNullify.count
    assert_equal root4.id, root4_child.parent_id

    root4.destroy

    assert_equal 1, TreeMixinNullify.count
    assert_nil root4_child.reload.parent_id
  end

  def test_is_root
    assert_equal true, @root1.root?
    assert_equal true, @root2.root?
    assert_equal true, @root3.root?

    assert_equal false, @root_child1.root?
    assert_equal false, @child1_child.root?
    assert_equal false, @child1_child_child.root?
    assert_equal false, @root_child2.root?
  end

  def test_is_leaf
    assert_equal true, @root2.leaf?
    assert_equal true, @root3.leaf?
    assert_equal true, @child1_child_child.leaf?
    assert_equal true, @root_child2.leaf?

    assert_equal false, @root1.leaf?
    assert_equal false, @root_child1.leaf?
    assert_equal false, @child1_child.leaf?
  end

  def test_tree_view
    assert_equal false, Mixin.respond_to?(:tree_view)
    Mixin.extend ActsAsTree::TreeView
    assert_equal true,  TreeMixin.respond_to?(:tree_view)

    tree_view_outputs = <<-END.gsub(/^ {6}/, '')
      root
       |_ 1
       |    |_ 2
       |        |_ 3
       |            |_ 4
       |    |_ 5
       |_ 6
       |_ 7
    END
    assert_equal tree_view_outputs, capture_stdout { TreeMixin.tree_view(:id) }
  end

  def test_tree_walker
    assert_equal false, TreeMixin.respond_to?(:walk_tree)
    assert_equal false, TreeMixin.new.respond_to?(:walk_tree)
    TreeMixin.extend ActsAsTree::TreeWalker
    assert_equal true,  TreeMixin.respond_to?(:walk_tree)
    assert_equal true,  TreeMixin.new.respond_to?(:walk_tree)

    walk_tree_dfs_output = <<-END.gsub(/^\s+/, '')
      1
      -2
      --3
      ---4
      -5
      6
      7
      END
    assert_equal walk_tree_dfs_output, capture_stdout { TreeMixin.walk_tree{|elem, level| puts "#{'-'*level}#{elem.id}"} }

    walk_tree_dfs_sub_output = <<-END.gsub(/^\s+/, '')
      2
      -3
      --4
      5
      END
    assert_equal walk_tree_dfs_sub_output, capture_stdout { @root1.walk_tree{|elem, level| puts "#{'-'*level}#{elem.id}"} }

    walk_tree_bfs_output = <<-END.gsub(/^\s+/, '')
      1
      6
      7
      -2
      -5
      --3
      ---4
      END
    assert_equal walk_tree_bfs_output, capture_stdout { TreeMixin.walk_tree(:algorithm => :bfs){|elem, level| puts "#{'-'*level}#{elem.id}"} }

    walk_tree_bfs_sub_output = <<-END.gsub(/^\s+/, '')
      2
      5
      -3
      --4
      END
    assert_equal walk_tree_bfs_sub_output, capture_stdout { @root1.walk_tree(:algorithm => :bfs){|elem, level| puts "#{'-'*level}#{elem.id}"} }
  end
end

class TestDeepDescendantsPerformance < MiniTest::Unit::TestCase
  def setup
    teardown_db
    setup_db
    @root1 = TreeMixin.create!
    create_cascade_children @root1, "root1", 10

    @root2        = TreeMixin.create!
    create_cascade_children @root2, "root2", 20

    @root3        = TreeMixin.create!
    create_cascade_children @root3, "root3", 30

    @root4        = TreeMixin.create!
    create_cascade_children @root4, "root4", 40

    @root5        = TreeMixin.create!
    create_cascade_children @root5, "root5", 50
  end

  def teardown
    teardown_db
  end

  def self.bench_range
    [1, 2, 3, 4, 5]
  end

  def bench_descendants
    skip("until I deal with the performance difference on travis")
    assert_performance_linear 0.99 do |x|
      obj = instance_variable_get "@root#{x}"
      obj.descendants
    end
  end

  def create_cascade_children parent, parent_name, count
    first_child_name = "@#{parent_name}_child1"
    first_record = TreeMixin.create! parent_id: parent.id
    instance_variable_set first_child_name, first_record

    (2...count).each do |child_count|
      name       = "@#{parent_name}_child#{child_count}"
      prev       = instance_variable_get "@#{parent_name}_child#{child_count - 1}"
      new_record = TreeMixin.create! parent_id: prev.id
      instance_variable_set name, new_record
    end
  end
end

class TreeTestWithEagerLoading < MiniTest::Unit::TestCase

  def setup
    teardown_db
    setup_db
    @root1        = TreeMixin.create!
    @root_child1  = TreeMixin.create! parent_id: @root1.id
    @child1_child = TreeMixin.create! parent_id: @root_child1.id
    @root_child2  = TreeMixin.create! parent_id: @root1.id
    @root2        = TreeMixin.create!
    @root3        = TreeMixin.create!

    @rc1 = RecursivelyCascadedTreeMixin.create!
    @rc2 = RecursivelyCascadedTreeMixin.create! parent_id: @rc1.id
    @rc3 = RecursivelyCascadedTreeMixin.create! parent_id: @rc2.id
    @rc4 = RecursivelyCascadedTreeMixin.create! parent_id: @rc3.id
  end

  def teardown
    teardown_db
  end

  def test_eager_association_loading
    roots = TreeMixin.includes(:children)
                     .where('mixins.parent_id IS NULL')
                     .order('mixins.id')

    assert_equal [@root1, @root2, @root3], roots

    assert_no_queries do
      assert_equal 2, roots[0].children.size
      assert_equal 0, roots[1].children.size
      assert_equal 0, roots[2].children.size
    end
  end

  def test_eager_association_loading_with_recursive_cascading_three_levels_has_many
    root_node = RecursivelyCascadedTreeMixin.includes({children: {children: :children}})
                                            .order('mixins.id')
                                            .first

    assert_equal @rc4, assert_no_queries { root_node.children.first.children.first.children.first }
  end

  def test_eager_association_loading_with_recursive_cascading_three_levels_has_one
    root_node = RecursivelyCascadedTreeMixin.includes({first_child: {first_child: :first_child}})
                                            .order('mixins.id')
                                            .first

    assert_equal @rc4, assert_no_queries { root_node.first_child.first_child.first_child }
  end

  def test_eager_association_loading_with_recursive_cascading_three_levels_belongs_to
    leaf_node = RecursivelyCascadedTreeMixin.includes({parent: {parent: :parent}})
                                            .order('mixins.id DESC')
                                            .first

    assert_equal @rc1, assert_no_queries { leaf_node.parent.parent.parent }
  end
end

class TreeTestWithoutOrder < MiniTest::Unit::TestCase

  def setup
    setup_db
    @root1 = TreeMixinWithoutOrder.create!
    @root2 = TreeMixinWithoutOrder.create!
  end

  def teardown
    teardown_db
  end

  def test_root
    assert [@root1, @root2].include? TreeMixinWithoutOrder.root
  end

  def test_roots
    assert_equal [], [@root1, @root2] - TreeMixinWithoutOrder.roots
  end
end

class UnsavedTreeTest < MiniTest::Unit::TestCase
  def setup
    setup_db
    @root       = TreeMixin.new
    @root_child = @root.children.build
  end

  def teardown
    teardown_db
  end

  def test_inverse_of
    # We want children to be aware of their parent before saving either
    assert_equal @root, @root_child.parent
  end
end


class TreeTestWithCounterCache < MiniTest::Unit::TestCase
  def setup
    teardown_db
    setup_db(true)

    @root          = TreeMixinWithCounterCache.create!
    @child1        = TreeMixinWithCounterCache.create! parent_id: @root.id
    @child1_child1 = TreeMixinWithCounterCache.create! parent_id: @child1.id
    @child2        = TreeMixinWithCounterCache.create! parent_id: @root.id

    [@root, @child1, @child1_child1, @child2].map(&:reload)
  end

  def teardown
    teardown_db
  end

  def test_counter_cache
    assert_equal 2, @root.children_count
    assert_equal 1, @child1.children_count
  end

  def test_update_parents_counter_cache
    @child1_child1.update_attributes(:parent_id => @root.id)
    assert_equal 3, @root.reload.children_count
    assert_equal 0, @child1.reload.children_count
  end

  def test_leaves
    assert_equal [@child1_child1, @child2], TreeMixinWithCounterCache.leaves

    assert !@root.leaf?
    assert @child2.leaf?
  end

  def test_counter_cache_being_used
    assert_no_queries { @root.leaf? }
    assert_no_queries { @child2.leaf? }
  end
end


class TreeTestWithTouch < MiniTest::Unit::TestCase
  def setup
    teardown_db
    setup_db

    @root  = TreeMixinWithTouch.create!
    @child = TreeMixinWithTouch.create! parent_id: @root.id
  end

  def teardown
    teardown_db
  end

  def test_updated_at
    previous_root_updated_at = @root.updated_at
    @child.update_attributes(:type => "new_type")
    @root.reload
    
    assert @root.updated_at != previous_root_updated_at
  end
end

class TreeTestWithNodePointingToSelf < MiniTest::Unit::TestCase
  def setup
    teardown_db
    setup_db

    @node = TreeMixin.create!
    @node.update_attribute(:parent_id, @node.id)
  end

  def teardown
    teardown_db
  end

  def test_root
    assert_equal @node, @node.root
  end

  def test_ancestors
    assert_equal [], @node.ancestors
  end
end
