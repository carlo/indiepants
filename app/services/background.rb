module Background
  extend self

  def go(&blk)
    Thread.new { backgroundable(&blk).call }
  end

  private

  def backgroundable(&blk)
    Proc.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          blk.call
        end
      end
    end
  end
end
