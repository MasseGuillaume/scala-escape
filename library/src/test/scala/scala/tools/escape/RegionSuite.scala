package scala.tools.escape

import scala.util.escape._

import org.junit.Test
import org.junit.Assert.assertEquals

class RegionSuite extends CompilerTesting {
  @Test def test1 = {
    trait Data[T] { 
	  def size: Long
	  def apply(i: Long)(implicit cc: T): Long 
	  def update(i: Long, x:Long)(implicit cc: T): Unit
	}
	trait Region { 
	  type Cap
	  def alloc(n: Long)(implicit c: Cap): Data[Cap] 
	}

	abstract class F[B] { def apply(r: Region): r.Cap -> B }

	def withRegion[T](n: Long)(f: F[T]): T = {
	  object cap
	  val r = new Region {
	    type Cap = Any
	    var data = new Array[Long](n.toInt)//malloc(n) 
	    var p = 0L
	    def alloc(n: Long)(implicit c: Cap) = new Data[Cap] {
	      def size = n
	      val addr = p
	      p += n
	      def apply(i: Long)(implicit c: Cap): Long = 
	        data((addr+i).toInt)
	      def update(i: Long, x:Long)(implicit cc: Cap): Unit = 
	        data((addr+i).toInt) = x
	    }
	  }
	  try f(r)(cap) finally r.data = null //free(r.data)
	}

	withRegion[Long](100) { r => c0 => 
	  //for @lcoal[Nothing], succeed
	  //for @local[Any]/@local, compile error
	  @local[Nothing] implicit val c = c0.asInstanceOf[r.Cap] // temporary bug!
	  val a = r.alloc(3)  // type: Data[r.Cap]
	  val b = r.alloc(4)
	  a(0) = 1
	  b(1) = 2
	  println(a(0))
	  println(b(1))
	  -1L
	}
	println()
  }
}