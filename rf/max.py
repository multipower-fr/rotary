import bbdevice.bb_api as bbapi
from com import Comm
import time
import sqlite3

class BB60C:
    def __init__(self):
        self.handle = bbapi.bb_open_device()["handle"]
        bbapi.bb_configure_center_span(self.handle, 3.0e9, 100.0e6)
        bbapi.bb_configure_ref_level(self.handle, -20.0)
        bbapi.bb_configure_gain_atten(self.handle, bbapi.BB_MAX_GAIN, 0)
        bbapi.bb_configure_sweep_coupling(
            self.handle,
            10.0e3,
            10.0e3,
            0.001,
            bbapi.BB_RBW_SHAPE_FLATTOP,
            bbapi.BB_NO_SPUR_REJECT,
        )
        bbapi.bb_configure_acquisition(
            self.handle, bbapi.BB_AVERAGE, bbapi.BB_LOG_SCALE
        )
        bbapi.bb_configure_proc_units(self.handle, bbapi.BB_POWER)

    def sweep(self):
        bbapi.bb_initiate(self.handle, bbapi.BB_SWEEPING, 0)
        self.query = bbapi.bb_query_trace_info(self.handle)
        trace_len = self.query["trace_len"]
        trace_max = bbapi.bb_fetch_trace_32f(self.handle, trace_len)["trace_max"]
        max_p = max(trace_max)
        return max_p
    
    def __del__(self):
        bbapi.bb_close_device(self.handle)

class SQL():
    def __init__(self, name) -> None:
        self.db = sqlite3.connect("rf/data.db")
        self.table = name
        cur = self.db.cursor()
        cur.execute(f"drop table if exists {self.table}")
        cur.execute(f"create table {self.table}(angle INT PRIMARY KEY NULL, power REAL)")
        self.db.commit()
    
    def push(self, vals: tuple[dict]):
        cur = self.db.cursor()
        cur.executemany(f"INSERT INTO {self.table} VALUES (:angle, :power)", vals)
        self.db.commit()

    def __del__(self):
        self.db.close()


def main():
    BB = BB60C()
    COM = Comm()
    DB = SQL("dir_1")
    measures: list[dict] = []
    for angle in range(0, 360, 10):
        COM.non_inter(f"$setPos;{angle}")
        time.sleep(2)
        measures.append({"angle": angle, "power": BB.sweep()})
    DB.push(tuple(measures))


if __name__ == "__main__":
    main()
