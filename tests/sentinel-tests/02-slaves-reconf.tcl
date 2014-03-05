# Check that slaves are reconfigured at a latter time if they are partitioned.
#
# Here we should test:
# 1) That slaves point to the new master after failover.
# 2) That partitioned slaves point to new master when they are partitioned
#    away during failover and return at a latter time.

source "../sentinel-tests/includes/init-tests.tcl"

proc 03_test_slaves_replication {} {
    uplevel 1 {
        test "Check that slaves replicate from current master" {
            set master_port [RI $master_id tcp_port]
            foreach_redis_id id {
                if {$id == $master_id} continue
                wait_for_condition 1000 50 {
                    [RI $id master_port] == $master_port
                } else {
                    fail "Redis slave $id is replicating from wrong master"
                }
            }
        }
    }
}

03_test_slaves_replication

test "Crash the master and force a failover" {
    set old_port [RI $master_id tcp_port]
    set addr [S 0 SENTINEL GET-MASTER-ADDR-BY-NAME mymaster]
    assert {[lindex $addr 1] == $old_port}
    kill_instance redis $master_id
    foreach_sentinel_id id {
        wait_for_condition 1000 50 {
            [lindex [S $id SENTINEL GET-MASTER-ADDR-BY-NAME mymaster] 1] != $old_port
        } else {
            fail "At least one Sentinel did not received failover info"
        }
    }
    restart_instance redis $master_id
    set addr [S 0 SENTINEL GET-MASTER-ADDR-BY-NAME mymaster]
    set master_id [get_instance_id_by_port redis [lindex $addr 1]]
}

03_test_slaves_replication
