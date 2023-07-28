import bbdevice.bb_api as bbapi
from com import Comm
import time
import sqlite3
import pandas as pd


class BB60C:
    def __init__(self):
        self.handle = bbapi.bb_open_device()["handle"]
        bbapi.bb_configure_center_span(self.handle, 2.825e9, 10.0e6)
        bbapi.bb_configure_ref_level(self.handle, -20.0)
        bbapi.bb_configure_gain_atten(self.handle, 2, 0)
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
        trace_max = bbapi.bb_fetch_trace_32f(
            self.handle, trace_len)["trace_max"]
        max_p = max(trace_max)
        return max_p

    def __del__(self):
        bbapi.bb_close_device(self.handle)


class SQL():
    def __init__(self, name) -> None:
        self.db = sqlite3.connect("rf/data2.db")
        self.table = name
        cur = self.db.cursor()
        cur.execute(f"drop table if exists {self.table}")
        cur.execute(
            f"create table {self.table}(angle INT PRIMARY KEY NULL, power REAL)")
        self.db.commit()

    def push(self, vals: tuple[dict]):
        cur = self.db.cursor()
        cur.executemany(
            f"INSERT INTO {self.table} VALUES (:angle, :power)", vals)
        self.db.commit()

    def __del__(self):
        self.db.close()


def zero(BB, COM, measures):
    COM.non_inter(f"$setPos;{0}")
    time.sleep(3)
    measures.append({"angle": 0, "power": BB.sweep()})
    return measures


def main():
    BB = BB60C()
    COM = Comm()
    DB = SQL("m1_10dbm")
    measures: list[dict] = []
    time.sleep(0)
    for angle in range(0, 360, 10):
        angl = []
        COM.non_inter(f"$setPos;{angle}")
        time.sleep(3)
        for _ in range(250):
            angl.append(BB.sweep())
            time.sleep(0.005)
        print(max(angl))
        measures.append({"angle": angle, "power": max(angl)})
    df = pd.DataFrame(measures)
    df.to_csv("rf/R1_2.csv", index=False)
    del DB
    DB = SQL("m2_10dbm")
    measures: list[dict] = []
    for angle in range(350, -10, -10):
        angl = []
        COM.non_inter(f"$setPos;{angle}")
        time.sleep(3)
        for _ in range(500):
            angl.append(BB.sweep())
            time.sleep(0.005)
        print(max(angl))
        measures.append({"angle": angle, "power": max(angl)})
    print(tuple(measures))
    df = pd.DataFrame(measures)
    df.to_csv("rf/R2.csv")
    del DB


if __name__ == "__main__":
    main()
