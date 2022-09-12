# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Copyright (c) 2006-2020, Salvatore Sanfilippo
# See bundled license file licenses/LICENSE.redis for details.

# This file is copied and modified from the Redis project,
# which started out as: https://github.com/redis/redis/blob/dbcc0a8/tests/unit/type/list.tcl

start_server {
    tags {"list"}
} {
    source "tests/unit/type/list-common.tcl"

    test {DEL a list} {
        assert_equal 1 [r del mylist2]
        assert_equal 0 [r exists mylist2]
        assert_equal 0 [r llen mylist2]
    }

    proc create_list {key entries} {
        r del $key
        foreach entry $entries { r rpush $key $entry }
        #assert_encoding quicklist $key
    }

    foreach {type large} [array get largevalue] {
        test "BLPOP, BRPOP: single existing list - $type" {
            set rd [redis_deferring_client]
            create_list blist "a b $large c d"

            $rd blpop blist 1
            assert_equal {blist a} [$rd read]
            $rd brpop blist 1
            assert_equal {blist d} [$rd read]

            $rd blpop blist 1
            assert_equal {blist b} [$rd read]
            $rd brpop blist 1
            assert_equal {blist c} [$rd read]
        }

        test "BLPOP, BRPOP: multiple existing lists - $type" {
            set rd [redis_deferring_client]
            create_list blist1 "a $large c"
            create_list blist2 "d $large f"

            $rd blpop blist1 blist2 1
            assert_equal {blist1 a} [$rd read]
            $rd brpop blist1 blist2 1
            assert_equal {blist1 c} [$rd read]
            assert_equal 1 [r llen blist1]
            assert_equal 3 [r llen blist2]

            $rd blpop blist2 blist1 1
            assert_equal {blist2 d} [$rd read]
            $rd brpop blist2 blist1 1
            assert_equal {blist2 f} [$rd read]
            assert_equal 1 [r llen blist1]
            assert_equal 1 [r llen blist2]
        }

        test "BLPOP, BRPOP: second list has an entry - $type" {
            set rd [redis_deferring_client]
            r del blist1
            create_list blist2 "d $large f"

            $rd blpop blist1 blist2 1
            assert_equal {blist2 d} [$rd read]
            $rd brpop blist1 blist2 1
            assert_equal {blist2 f} [$rd read]
            assert_equal 0 [r llen blist1]
            assert_equal 1 [r llen blist2]
        }

        # test "BRPOPLPUSH - $type" {
        #     r del target

        #     set rd [redis_deferring_client]
        #     create_list blist "a b $large c d"

        #     $rd brpoplpush blist target 1
        #     assert_equal d [$rd read]

        #     assert_equal d [r rpop target]
        #     assert_equal "a b $large c" [r lrange blist 0 -1]
        # }
    }

    test "BLPOP with same key multiple times should work (issue #801)" {
        set rd [redis_deferring_client]
        r del list1 list2

        # Data arriving after the BLPOP.
        $rd blpop list1 list2 list2 list1 0
        r lpush list1 a
        assert_equal [$rd read] {list1 a}
        $rd blpop list1 list2 list2 list1 0
        r lpush list2 b
        assert_equal [$rd read] {list2 b}

        # Data already there.
        r lpush list1 a
        r lpush list2 b
        $rd blpop list1 list2 list2 list1 0
        assert_equal [$rd read] {list1 a}
        $rd blpop list1 list2 list2 list1 0
        assert_equal [$rd read] {list2 b}
    }

    test "BLPOP with variadic LPUSH" {
        set rd [redis_deferring_client]
        r del blist target
        if {$::valgrind} {after 100}
        $rd blpop blist 0
        if {$::valgrind} {after 100}
        assert_equal 2 [r lpush blist foo bar]
        if {$::valgrind} {after 100}
        assert_equal {blist bar} [$rd read]
        assert_equal foo [lindex [r lrange blist 0 -1] 0]
    }

    # test "BRPOPLPUSH with zero timeout should block indefinitely" {
    #     set rd [redis_deferring_client]
    #     r del blist target
    #     $rd brpoplpush blist target 0
    #     after 1000
    #     r rpush blist foo
    #     assert_equal foo [$rd read]
    #     assert_equal {foo} [r lrange target 0 -1]
    # }

    # test "BRPOPLPUSH with a client BLPOPing the target list" {
    #     set rd [redis_deferring_client]
    #     set rd2 [redis_deferring_client]
    #     r del blist target
    #     $rd2 blpop target 0
    #     $rd brpoplpush blist target 0
    #     after 1000
    #     r rpush blist foo
    #     assert_equal foo [$rd read]
    #     assert_equal {target foo} [$rd2 read]
    #     assert_equal 0 [r exists target]
    # }

    # test "BRPOPLPUSH with wrong source type" {
    #     set rd [redis_deferring_client]
    #     r del blist target
    #     r set blist nolist
    #     $rd brpoplpush blist target 1
    #     assert_error "*WRONGTYPE*" {$rd read}
    # }

    # test "BRPOPLPUSH with wrong destination type" {
    #     set rd [redis_deferring_client]
    #     r del blist target
    #     r set target nolist
    #     r lpush blist foo
    #     $rd brpoplpush blist target 1
    #     assert_error "*WRONGTYPE*" {$rd read}

    #     set rd [redis_deferring_client]
    #     r del blist target
    #     r set target nolist
    #     $rd brpoplpush blist target 0
    #     after 1000
    #     r rpush blist foo
    #     assert_error "*WRONGTYPE*" {$rd read}
    #     assert_equal {foo} [r lrange blist 0 -1]
    # }

    # test "BRPOPLPUSH maintains order of elements after failure" {
    #     set rd [redis_deferring_client]
    #     r del blist target
    #     r set target nolist
    #     $rd brpoplpush blist target 0
    #     r rpush blist a b c
    #     assert_error "*WRONGTYPE*" {$rd read}
    #     r lrange blist 0 -1
    # } {a b c}

    # test "BRPOPLPUSH with multiple blocked clients" {
    #     set rd1 [redis_deferring_client]
    #     set rd2 [redis_deferring_client]
    #     r del blist target1 target2
    #     r set target1 nolist
    #     $rd1 brpoplpush blist target1 0
    #     $rd2 brpoplpush blist target2 0
    #     r lpush blist foo

    #     assert_error "*WRONGTYPE*" {$rd1 read}
    #     assert_equal {foo} [$rd2 read]
    #     assert_equal {foo} [r lrange target2 0 -1]
    # }

    # test "Linked BRPOPLPUSH" {
    #   set rd1 [redis_deferring_client]
    #   set rd2 [redis_deferring_client]
    #   r del list1 list2 list3
    #   $rd1 brpoplpush list1 list2 0
    #   $rd2 brpoplpush list2 list3 0
    #   r rpush list1 foo
    #   assert_equal {} [r lrange list1 0 -1]
    #   assert_equal {} [r lrange list2 0 -1]
    #   assert_equal {foo} [r lrange list3 0 -1]
    # }

    # test "Circular BRPOPLPUSH" {
    #   set rd1 [redis_deferring_client]
    #   set rd2 [redis_deferring_client]
    #   r del list1 list2
    #   $rd1 brpoplpush list1 list2 0
    #   $rd2 brpoplpush list2 list1 0
    #   r rpush list1 foo
    #   assert_equal {foo} [r lrange list1 0 -1]
    #   assert_equal {} [r lrange list2 0 -1]
    # }

    # test "Self-referential BRPOPLPUSH" {
    #   set rd [redis_deferring_client]
    #   r del blist
    #   $rd brpoplpush blist blist 0
    #   r rpush blist foo
    #   assert_equal {foo} [r lrange blist 0 -1]
    # }

    # test {BRPOPLPUSH timeout} {
    #   set rd [redis_deferring_client]

    #   $rd brpoplpush foo_list bar_list 1
    #   after 2000
    #   $rd read
    # } {}

    foreach {pop} {BLPOP BRPOP} {
        test "$pop: with single empty list argument" {
            set rd [redis_deferring_client]
            r del blist1
            $rd $pop blist1 1
            r rpush blist1 foo
            assert_equal {blist1 foo} [$rd read]
            assert_equal 0 [r exists blist1]
        }

        test "$pop: with negative timeout" {
            set rd [redis_deferring_client]
            $rd $pop blist1 -1
            assert_error "*negative*" {$rd read}
        }

        # test "$pop: with non-integer timeout" {
        #     set rd [redis_deferring_client]
        #     $rd $pop blist1 1.1
        #     assert_error "ERR*not an integer*" {$rd read}
        # }

        test "$pop: with zero timeout should block indefinitely" {
            # To test this, use a timeout of 0 and wait a second.
            # The blocking pop should still be waiting for a push.
            set rd [redis_deferring_client]
            $rd $pop blist1 0
            after 1000
            r rpush blist1 foo
            assert_equal {blist1 foo} [$rd read]
        }

        test "$pop: second argument is not a list" {
            set rd [redis_deferring_client]
            r del blist1 blist2
            r set blist2 nolist
            $rd $pop blist1 blist2 1
            assert_error "*WRONGTYPE*" {$rd read}
        }

        test "$pop: timeout" {
            set rd [redis_deferring_client]
            r del blist1 blist2
            $rd $pop blist1 blist2 1
            assert_equal {} [$rd read]
        }

        test "$pop: arguments are empty" {
            set rd [redis_deferring_client]
            r del blist1 blist2

            $rd $pop blist1 blist2 1
            r rpush blist1 foo
            assert_equal {blist1 foo} [$rd read]
            assert_equal 0 [r exists blist1]
            assert_equal 0 [r exists blist2]

            $rd $pop blist1 blist2 1
            r rpush blist2 foo
            assert_equal {blist2 foo} [$rd read]
            assert_equal 0 [r exists blist1]
            assert_equal 0 [r exists blist2]
        }
    }

    test {LPUSHX, RPUSHX - generic} {
        r del xlist
        assert_equal 0 [r lpushx xlist a]
        assert_equal 0 [r llen xlist]
        assert_equal 0 [r rpushx xlist a]
        assert_equal 0 [r llen xlist]
    }

    foreach {type large} [array get largevalue] {
        test "LPUSHX, RPUSHX - $type" {
            create_list xlist "$large c"
            assert_equal 3 [r rpushx xlist d]
            assert_equal 4 [r lpushx xlist a]
            assert_equal 6 [r rpushx xlist 42 x]
            assert_equal 9 [r lpushx xlist y3 y2 y1]
            assert_equal "y1 y2 y3 a $large c d 42 x" [r lrange xlist 0 -1]
        }

        test "LINSERT - $type" {
            create_list xlist "a $large c d"
            assert_equal 5 [r linsert xlist before c zz] "before c"
            assert_equal "a $large zz c d" [r lrange xlist 0 10] "lrangeA"
            assert_equal 6 [r linsert xlist after c yy] "after c"
            assert_equal "a $large zz c yy d" [r lrange xlist 0 10] "lrangeB"
            assert_equal 7 [r linsert xlist after d dd] "after d"
            assert_equal -1 [r linsert xlist after bad ddd] "after bad"
            assert_equal "a $large zz c yy d dd" [r lrange xlist 0 10] "lrangeC"
            assert_equal 8 [r linsert xlist before a aa] "before a"
            assert_equal -1 [r linsert xlist before bad aaa] "before bad"
            assert_equal "aa a $large zz c yy d dd" [r lrange xlist 0 10] "lrangeD"

            # check inserting integer encoded value
            assert_equal 9 [r linsert xlist before aa 42] "before aa"
            assert_equal 42 [r lrange xlist 0 0] "lrangeE"
        }
    }

    test {LINSERT raise error on bad syntax} {
        catch {[r linsert xlist aft3r aa 42]} e
        set e
    } {*syntax*error*}

    foreach {type num} {quicklist 250 quicklist 500} {
        proc check_numbered_list_consistency {key} {
            set len [r llen $key]
            for {set i 0} {$i < $len} {incr i} {
                assert_equal $i [r lindex $key $i]
                assert_equal [expr $len-1-$i] [r lindex $key [expr (-$i)-1]]
            }
        }

        proc check_random_access_consistency {key} {
            set len [r llen $key]
            for {set i 0} {$i < $len} {incr i} {
                set rint [expr int(rand()*$len)]
                assert_equal $rint [r lindex $key $rint]
                assert_equal [expr $len-1-$rint] [r lindex $key [expr (-$rint)-1]]
            }
        }

        test "LINDEX consistency test - $type" {
            r del mylist
            for {set i 0} {$i < $num} {incr i} {
                r rpush mylist $i
            }
            #assert_encoding $type mylist
            check_numbered_list_consistency mylist
        }

        test "LINDEX random access - $type" {
            #assert_encoding $type mylist
            check_random_access_consistency mylist
        }

        test "Check if list is still ok after a DEBUG RELOAD - $type" {
            #assert_encoding $type mylist
            check_numbered_list_consistency mylist
            check_random_access_consistency mylist
        }
    }

    test {LLEN against non-list value error} {
        r del mylist
        r set mylist foobar
        assert_error *WRONGTYPE* {r llen mylist}
    }

    test {LLEN against non existing key} {
        assert_equal 0 [r llen not-a-key]
    }

    test {LINDEX against non-list value error} {
        assert_error *WRONGTYPE* {r lindex mylist 0}
    }

    test {LINDEX against non existing key} {
        assert_equal "" [r lindex not-a-key 10]
    }

    test {LPUSH against non-list value error} {
        assert_error *WRONGTYPE* {r lpush mylist 0}
    }

    test {RPUSH against non-list value error} {
        assert_error *WRONGTYPE* {r rpush mylist 0}
    }

    foreach {type large} [array get largevalue] {
        test "RPOPLPUSH base case - $type" {
            r del mylist1 mylist2
            create_list mylist1 "a $large c d"
            assert_equal d [r rpoplpush mylist1 mylist2]
            assert_equal c [r rpoplpush mylist1 mylist2]
            assert_equal "a $large" [r lrange mylist1 0 -1]
            assert_equal "c d" [r lrange mylist2 0 -1]
            #assert_encoding quicklist mylist2
        }

        test "RPOPLPUSH with the same list as src and dst - $type" {
            create_list mylist "a $large c"
            assert_equal "a $large c" [r lrange mylist 0 -1]
            assert_equal c [r rpoplpush mylist mylist]
            assert_equal "c a $large" [r lrange mylist 0 -1]
        }

        foreach {othertype otherlarge} [array get largevalue] {
            test "RPOPLPUSH with $type source and existing target $othertype" {
                create_list srclist "a b c $large"
                create_list dstlist "$otherlarge"
                assert_equal $large [r rpoplpush srclist dstlist]
                assert_equal c [r rpoplpush srclist dstlist]
                assert_equal "a b" [r lrange srclist 0 -1]
                assert_equal "c $large $otherlarge" [r lrange dstlist 0 -1]

                # When we rpoplpush'ed a large value, dstlist should be
                # converted to the same encoding as srclist.
                if {$type eq "linkedlist"} {
                    #assert_encoding quicklist dstlist
                }
            }
        }
    }

    test {RPOPLPUSH against non existing key} {
        r del srclist dstlist
        assert_equal {} [r rpoplpush srclist dstlist]
        assert_equal 0 [r exists srclist]
        assert_equal 0 [r exists dstlist]
    }

    test {RPOPLPUSH against non list src key} {
        r del srclist dstlist
        r set srclist x
        assert_error *WRONGTYPE* {r rpoplpush srclist dstlist}
        assert_type string srclist
        assert_equal 0 [r exists newlist]
    }

    test {RPOPLPUSH against non list dst key} {
        create_list srclist {a b c d}
        r set dstlist x
        assert_error *WRONGTYPE* {r rpoplpush srclist dstlist}
        assert_type string dstlist
        assert_equal {a b c d} [r lrange srclist 0 -1]
    }

    test {RPOPLPUSH against non existing src key} {
        r del srclist dstlist
        assert_equal {} [r rpoplpush srclist dstlist]
    } {}

    foreach {type large} [array get largevalue] {
        test "Basic LPOP/RPOP - $type" {
            create_list mylist "$large 1 2"
            assert_equal $large [r lpop mylist]
            assert_equal 2 [r rpop mylist]
            assert_equal 1 [r lpop mylist]
            assert_equal 0 [r llen mylist]

            # pop on empty list
            assert_equal {} [r lpop mylist]
            assert_equal {} [r rpop mylist]
        }
    }

    test {LPOP/RPOP against non list value} {
        r set notalist foo
        assert_error *WRONGTYPE* {r lpop notalist}
        assert_error *WRONGTYPE* {r rpop notalist}
    }

    test "LPOP/RPOP with wrong number of arguments" {
        assert_error {*wrong number of arguments*} {r lpop key 1 1}
        assert_error {*wrong number of arguments*} {r rpop key 2 2}
    }

    test {RPOP/LPOP with the optional count argument} {
        assert_equal 7 [r lpush listcount aa bb cc dd ee ff gg]
        assert_equal {gg} [r lpop listcount 1]
        assert_equal {ff ee} [r lpop listcount 2]
        assert_equal {aa bb} [r rpop listcount 2]
        assert_equal {cc} [r rpop listcount 1]
        assert_equal {dd} [r rpop listcount 123]
        assert_error "*ERR*range*" {r lpop forbarqaz -123}
    }

    test "LPOP/RPOP with the count 0 returns an empty array" {
        # Make sure we can distinguish between an empty array and a null response
        r readraw 1

        r lpush listcount zero
        assert_equal {*0} [r lpop listcount 0]
        assert_equal {*0} [r rpop listcount 0]

        r readraw 0
    }

    test "LPOP/RPOP against non existing key" {
        r readraw 1

        r del non_existing_key
        assert_equal [r lpop non_existing_key] {$-1}
        assert_equal [r rpop non_existing_key] {$-1}

        r readraw 0
    }

    test "LPOP/RPOP with <count> against non existing key" {
        r readraw 1

        r del non_existing_key

        assert_equal [r lpop non_existing_key 0] {*-1}
        assert_equal [r lpop non_existing_key 1] {*-1}

        assert_equal [r rpop non_existing_key 0] {*-1}
        assert_equal [r rpop non_existing_key 1] {*-1}

        r readraw 0
    }

    foreach {type num} {quicklist 250 quicklist 500} {
        test "Mass RPOP/LPOP - $type" {
            r del mylist
            set sum1 0
            for {set i 0} {$i < $num} {incr i} {
                r lpush mylist $i
                incr sum1 $i
            }
            #assert_encoding $type mylist
            set sum2 0
            for {set i 0} {$i < [expr $num/2]} {incr i} {
                incr sum2 [r lpop mylist]
                incr sum2 [r rpop mylist]
            }
            assert_equal $sum1 $sum2
        }
    }

    foreach {type large} [array get largevalue] {
        test "LRANGE basics - $type" {
            create_list mylist "$large 1 2 3 4 5 6 7 8 9"
            assert_equal {1 2 3 4 5 6 7 8} [r lrange mylist 1 -2]
            assert_equal {7 8 9} [r lrange mylist -3 -1]
            assert_equal {4} [r lrange mylist 4 4]
        }

        test "LRANGE inverted indexes - $type" {
            create_list mylist "$large 1 2 3 4 5 6 7 8 9"
            assert_equal {} [r lrange mylist 6 2]
        }

        test "LRANGE out of range indexes including the full list - $type" {
            create_list mylist "$large 1 2 3"
            assert_equal "$large 1 2 3" [r lrange mylist -1000 1000]
        }

        test "LRANGE out of range negative end index - $type" {
            create_list mylist "$large 1 2 3"
            assert_equal $large [r lrange mylist 0 -4]
            assert_equal {} [r lrange mylist 0 -5]
        }
    }

    test {LRANGE against non existing key} {
        assert_equal {} [r lrange nosuchkey 0 1]
    }

    foreach {type large} [array get largevalue] {
        proc trim_list {type min max} {
            upvar 1 large large
            r del mylist
            create_list mylist "1 2 3 4 $large"
            r ltrim mylist $min $max
            r lrange mylist 0 -1
        }

        test "LTRIM basics - $type" {
            assert_equal "1" [trim_list $type 0 0]
            assert_equal "1 2" [trim_list $type 0 1]
            assert_equal "1 2 3" [trim_list $type 0 2]
            assert_equal "2 3" [trim_list $type 1 2]
            assert_equal "2 3 4 $large" [trim_list $type 1 -1]
            assert_equal "2 3 4" [trim_list $type 1 -2]
            assert_equal "4 $large" [trim_list $type -2 -1]
            assert_equal "$large" [trim_list $type -1 -1]
            assert_equal "1 2 3 4 $large" [trim_list $type -5 -1]
            assert_equal "1 2 3 4 $large" [trim_list $type -10 10]
            assert_equal "1 2 3 4 $large" [trim_list $type 0 5]
            assert_equal "1 2 3 4 $large" [trim_list $type 0 10]
        }

        test "LTRIM out of range negative end index - $type" {
            assert_equal {1} [trim_list $type 0 -5]
            assert_equal {} [trim_list $type 0 -6]
        }

        test "LTRIM lrem elements after ltrim list - $type" {
            create_list myotherlist "0 1 2 3 4 3 6 7 3 9"
            assert_equal "OK" [r ltrim myotherlist 2 -3]
            assert_equal "2 3 4 3 6 7" [r lrange myotherlist 0 -1]
            assert_equal 2 [r lrem myotherlist 4 3]
            assert_equal "2 4 6 7" [r lrange myotherlist 0 -1]
        }

        test "LTRIM linsert elements after ltrim list - $type" {
            create_list myotherlist1 "0 1 2 3 4 3 6 7 3 9"
            assert_equal "OK" [r ltrim myotherlist1 2 -3]
            assert_equal "2 3 4 3 6 7" [r lrange myotherlist1 0 -1]
            assert_equal -1 [r linsert myotherlist1 before 9 0]
            assert_equal 7 [r linsert myotherlist1 before 4 0]
            assert_equal "2 3 0 4 3 6 7" [r lrange myotherlist1 0 -1]
        }
    }

    foreach {type large} [array get largevalue] {
        test "LSET - $type" {
            create_list mylist "99 98 $large 96 95"
            r lset mylist 1 foo
            r lset mylist -1 bar
            assert_equal "99 foo $large 96 bar" [r lrange mylist 0 -1]
        }

        test "LSET out of range index - $type" {
            assert_error ERR*range* {r lset mylist 10 foo}
        }
    }

    test {LSET against non existing key} {
        assert_error ERR*NotFound* {r lset nosuchkey 10 foo}
    }

    test {LSET against non list value} {
        r set nolist foobar
        assert_error *WRONGTYPE* {r lset nolist 0 foo}
    }

    foreach {type e} [array get largevalue] {
        test "LREM remove all the occurrences - $type" {
            create_list mylist "$e foo bar foobar foobared zap bar test foo"
            assert_equal 2 [r lrem mylist 0 bar]
            assert_equal "$e foo foobar foobared zap test foo" [r lrange mylist 0 -1]
        }

        test "LREM remove the first occurrence - $type" {
            assert_equal 1 [r lrem mylist 1 foo]
            assert_equal "$e foobar foobared zap test foo" [r lrange mylist 0 -1]
        }

        test "LREM remove non existing element - $type" {
            assert_equal 0 [r lrem mylist 1 nosuchelement]
            assert_equal "$e foobar foobared zap test foo" [r lrange mylist 0 -1]
        }

        test "LREM starting from tail with negative count - $type" {
            create_list mylist "$e foo bar foobar foobared zap bar test foo foo"
            assert_equal 1 [r lrem mylist -1 bar]
            assert_equal "$e foo bar foobar foobared zap test foo foo" [r lrange mylist 0 -1]
        }

        test "LREM starting from tail with negative count (2) - $type" {
            assert_equal 2 [r lrem mylist -2 foo]
            assert_equal "$e foo bar foobar foobared zap test" [r lrange mylist 0 -1]
        }

        test "LREM deleting objects that may be int encoded - $type" {
            create_list myotherlist "$e 1 2 3"
            assert_equal 1 [r lrem myotherlist 1 2]
            assert_equal 3 [r llen myotherlist]
        }

        test "LREM remove elements in repeating list - $type" {
            create_list myotherlist1 "$e a b c d e f a f a f"
            assert_equal 1 [r lrem myotherlist1 1 f]
            assert_equal "$e a b c d e a f a f" [r lrange myotherlist1 0 -1]
            assert_equal 2 [r lrem myotherlist1 0 f]
            assert_equal "$e a b c d e a a" [r lrange myotherlist1 0 -1]
        }
    }

    # test "Regression for bug 593 - chaining BRPOPLPUSH with other blocking cmds" {
    #     set rd1 [redis_deferring_client]
    #     set rd2 [redis_deferring_client]

    #     $rd1 brpoplpush a b 0
    #     $rd1 brpoplpush a b 0
    #     $rd2 brpoplpush b c 0
    #     after 1000
    #     r lpush a data
    #     $rd1 close
    #     $rd2 close
    #     r ping
    # } {PONG}

    test {Test LMOVE on different keys} {
        r RPUSH list1{t} "1"
        r RPUSH list1{t} "2"
        r RPUSH list1{t} "3"
        r RPUSH list1{t} "4"
        r RPUSH list1{t} "5"

        r LMOVE list1{t} list2{t} RIGHT LEFT
        r LMOVE list1{t} list2{t} LEFT RIGHT
        assert_equal [r llen list1{t}] 3
        assert_equal [r llen list2{t}] 2
        assert_equal [r lrange list1{t} 0 -1] {2 3 4}
        assert_equal [r lrange list2{t} 0 -1] {5 1}
    }

    foreach from {LEFT RIGHT} {
        foreach to {LEFT RIGHT} {
            test "LMOVE $from $to on the list node" {
                    r del target_key{t}
                    r rpush target_key{t} 1

                    set rd [redis_deferring_client]
                    create_list list{t} "a b c d"
                    $rd lmove list{t} target_key{t} $from $to
                    set elem [$rd read]

                    if {$from eq "RIGHT"} {
                        assert_equal d $elem
                        assert_equal "a b c" [r lrange list{t} 0 -1]
                    } else {
                        assert_equal a $elem
                        assert_equal "b c d" [r lrange list{t} 0 -1]
                    }
                    if {$to eq "RIGHT"} {
                        assert_equal $elem [r rpop target_key{t}]
                    } else {
                        assert_equal $elem [r lpop target_key{t}]
                    }

                    $rd close
                }
            }
        }
}
