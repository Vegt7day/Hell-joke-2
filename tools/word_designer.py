#!/usr/bin/env python3
"""文字地狱 - 单字交互设计管理工具

用法: python tools/word_designer.py
依赖: tkinter (Python 内置)
"""

import json
import os
import sys
from pathlib import Path
from tkinter import (
    Tk, Toplevel, Frame, Label, Entry, Text, Button, Listbox,
    Scrollbar, LabelFrame, OptionMenu, StringVar, IntVar, BooleanVar,
    Checkbutton, ttk, messagebox, filedialog, END, BOTH, LEFT, RIGHT,
    TOP, BOTTOM, X, Y, W, E, N, S, VERTICAL, HORIZONTAL, DISABLED, NORMAL,
)
from tkinter import font as tkfont
from dataclasses import dataclass, field, asdict
from typing import Dict, List, Optional, Tuple

# ── 数据结构 ──────────────────────────────────────────────────────

CATEGORIES = ["召唤", "强化", "防御", "辅助", "建造", "反应"]
CATEGORY_COLORS = {
    "召唤": "#4A90D9",
    "强化": "#5CB85C",
    "防御": "#F0AD4E",
    "辅助": "#9B59B6",
    "建造": "#95A5A6",
    "反应": "#E74C3C",
}

INTERACTION_EFFECTS = [
    "无效", "增伤", "减伤", "治愈", "加速", "减速",
    "冻结", "眩晕", "燃烧", "腐蚀", "导电", "石化",
    "击退", "穿透", "护盾", "诅咒", "净化", "点燃",
    "削弱", "强化", "叠加", "抵消", "扩散", "激活",
]

ALL_CHARS = [
    # 召唤
    "商", "剑", "枪", "刀", "矛", "弓", "弹", "魔", "暴", "幻", "鬼",
    # 强化
    "力", "速", "盾", "坚", "锐", "疾", "愈", "狂", "圣", "破", "灵",
    "弱", "缓", "毒", "晕", "脆", "沉", "绑", "盲",
    # 防御
    "壁", "重", "甲",
    # 辅助
    "护", "恢", "强",
    # 建造
    "土", "界", "木", "网", "压", "梯", "炸",
    # 反应
    "火", "水", "风", "腐", "冰", "雷", "光", "暗",
    # 玩家
    "冲", "墨", "守",
]

DEFAULT_CATEGORY_MAP = {
    "商": "召唤", "剑": "召唤", "枪": "召唤", "刀": "召唤", "矛": "召唤",
    "弓": "召唤", "弹": "召唤", "魔": "召唤", "暴": "召唤", "幻": "召唤", "鬼": "召唤",
    "力": "强化", "速": "强化", "盾": "强化", "坚": "强化", "锐": "强化",
    "疾": "强化", "愈": "强化", "狂": "强化", "圣": "强化", "破": "强化", "灵": "强化",
    "弱": "强化", "缓": "强化", "毒": "强化", "晕": "强化", "脆": "强化",
    "沉": "强化", "绑": "强化", "盲": "强化",
    "壁": "防御", "重": "防御", "甲": "防御",
    "护": "辅助", "恢": "辅助", "强": "辅助",
    "土": "建造", "界": "建造", "木": "建造", "网": "建造", "压": "建造",
    "梯": "建造", "炸": "建造",
    "火": "反应", "水": "反应", "风": "反应", "腐": "反应",
    "冰": "反应", "雷": "反应", "光": "反应", "暗": "反应",
    "冲": "反应", "墨": "反应", "守": "反应",
}

# ── 数据模型 ──────────────────────────────────────────────────────

@dataclass
class WordData:
    char: str
    name: str = ""
    category: str = "召唤"
    subtype: str = ""           # 进攻/防御/辅助/双刃剑/增益/减益/消耗/耐久等
    ink_cost: int = 1
    stack: int = 1              # 消耗型次数
    is_durable: bool = False    # 是否耐久型(玩家专属)
    cooldown: float = 0.0
    hp: int = 0
    damage: int = 0
    speed: int = 0
    duration: float = 0.0
    range_val: str = ""
    directional: bool = False
    effect: str = ""
    special: str = ""
    description: str = ""
    # 交互
    interactions: Dict[str, str] = field(default_factory=dict)

@dataclass
class DesignData:
    words: List[WordData] = field(default_factory=list)
    interactions: Dict[str, Dict[str, str]] = field(default_factory=dict)
    notes: str = ""

    def get_word(self, char: str) -> Optional[WordData]:
        for w in self.words:
            if w.char == char:
                return w
        return None

    def save_json(self, path: str):
        data = {
            "words": [asdict(w) for w in self.words],
            "interactions": self.interactions,
            "notes": self.notes,
        }
        Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def load_json(self, path: str):
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        self.words = [WordData(**w) for w in data.get("words", [])]
        self.interactions = data.get("interactions", {})
        self.notes = data.get("notes", "")

    def to_markdown(self) -> str:
        lines = [
            "# 单字设计与交互矩阵",
            "",
            "> 文字地狱重制版 | 自动生成",
            "",
            "---",
            "",
        ]
        # 分类汇总
        lines.append("## 一、道具体系总览")
        lines.append("")
        lines.append("| 类型 | 代号 | 墨水消耗 | 使用次数 | 特点 |")
        lines.append("|------|------|----------|----------|------|")
        lines.append("| **消耗型** | CONSUMABLE | **不消耗** | 用完即无 | 一次性投入，立即生效 |")
        lines.append("| **耐久型** | DURABLE | **每次消耗** | 无限次 | 可重复使用，每次消耗墨水 |")
        lines.append("")
        lines.append("> **注意**：除玩家专属的冲、墨、守外，其余所有道具均为**一次性消耗型**。")
        lines.append("")
        lines.append("---")
        lines.append("")

        # 玩家专属
        player_words = [w for w in self.words if w.is_durable]
        if player_words:
            lines.append("## 二、玩家专属耐久型")
            lines.append("")
            lines.append("| 单字 | 名称 | 墨水 | 冷却 | 效果 | 特殊能力 |")
            lines.append("|------|------|------|------|------|----------|")
            for w in player_words:
                lines.append(f"| {w.char} | {w.name} | {w.ink_cost} | {w.cooldown}s | {w.effect} | {w.special} |")
            lines.append("")
            lines.append("---")
            lines.append("")

        # 各分类
        section_num = 2
        for cat in CATEGORIES:
            section_num += 1
            cn_num = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
            num_str = cn_num[section_num] if section_num < len(cn_num) else str(section_num)
            cat_words = [w for w in self.words if w.category == cat and not w.is_durable]
            if not cat_words:
                continue

            lines.append(f"## {num_str}、{cat}类单字")
            lines.append("")
            lines.append(f"### {section_num}.1 消耗型{cat}（用完即无，不消耗墨水）")
            lines.append("")

            # 根据分类决定表头
            if cat == "召唤":
                lines.append("| 单字 | 名称 | 次数 | 血量 | 伤害 | 移速 | 攻击范围 | 特殊能力 |")
                lines.append("|------|------|------|------|------|------|----------|----------|")
                for w in cat_words:
                    lines.append(f"| {w.char} | {w.name} | {w.stack} | {w.hp} | {w.damage} | {w.speed} | {w.range_val} | {w.special} |")
            elif cat == "强化":
                lines.append("| 单字 | 名称 | 次数 | 效果 | 持续时间 | 特殊效果 |")
                lines.append("|------|------|------|------|----------|----------|")
                for w in cat_words:
                    lines.append(f"| {w.char} | {w.name} | {w.stack} | {w.effect} | {w.duration}s | {w.special} |")
            elif cat == "防御":
                lines.append("| 单字 | 名称 | 次数 | 血量 | 减伤 | 移速 | 特殊能力 |")
                lines.append("|------|------|------|------|------|------|----------|")
                for w in cat_words:
                    lines.append(f"| {w.char} | {w.name} | {w.stack} | {w.hp} | {w.damage}% | {w.speed} | {w.special} |")
            elif cat == "辅助":
                lines.append("| 单字 | 名称 | 次数 | 效果 | 持续时间 | 特殊能力 |")
                lines.append("|------|------|------|------|----------|----------|")
                for w in cat_words:
                    lines.append(f"| {w.char} | {w.name} | {w.stack} | {w.effect} | {w.duration}s | {w.special} |")
            elif cat == "建造":
                lines.append("| 单字 | 名称 | 次数 | 生命 | 碰撞规则 | 特殊能力 |")
                lines.append("|------|------|------|------|----------|----------|")
                for w in cat_words:
                    lines.append(f"| {w.char} | {w.name} | {w.stack} | {w.hp} | {w.range_val} | {w.special} |")
            elif cat == "反应":
                lines.append("| 单字 | 名称 | 次数 | 范围 | 持续时间 | 方向性 | 特殊能力 |")
                lines.append("|------|------|------|------|----------|--------|----------|")
                for w in cat_words:
                    d = "是" if w.directional else "否"
                    lines.append(f"| {w.char} | {w.name} | {w.stack} | {w.range_val} | {w.duration}s | {d} | {w.special} |")

            lines.append("")
            lines.append("---")
            lines.append("")

        # 交互矩阵
        lines.append("## 交互矩阵")
        lines.append("")
        chars = sorted(set(w.char for w in self.words))
        lines.append("| 作用方 \\ 承受方 | " + " | ".join(chars) + " |")
        lines.append("|" + "|".join(["---"] * (len(chars) + 1)) + "|")
        for src in chars:
            row = f"| **{src}** |"
            for tgt in chars:
                if src == tgt:
                    row += " - |"
                else:
                    val = self.interactions.get(src, {}).get(tgt, "无效")
                    row += f" {val} |"
            lines.append(row)
        lines.append("")

        if self.notes:
            lines.append("---")
            lines.append("")
            lines.append("## 备注")
            lines.append("")
            lines.append(self.notes)
            lines.append("")

        return "\n".join(lines)


# ── GUI 主窗口 ────────────────────────────────────────────────────

class WordDesignerApp:
    def __init__(self, root: Tk):
        self.root = root
        self.root.title("文字地狱 - 单字交互设计管理器")
        self.root.geometry("1400x900")
        self.root.minsize(1000, 700)

        self.data = DesignData()
        self.current_char = None
        self._load_default()

        self._build_ui()
        self._refresh_char_list()

    def _load_default(self):
        for char in ALL_CHARS:
            self.data.words.append(WordData(
                char=char,
                name=f"文字{char}",
                category=DEFAULT_CATEGORY_MAP.get(char, "召唤"),
            ))

    def _build_ui(self):
        # 左侧: 字列表 + 分类筛选
        left = Frame(self.root, width=200)
        left.pack(side=LEFT, fill=Y, padx=5, pady=5)

        Label(left, text="单字列表", font=("", 12, "bold")).pack(anchor=W)

        # 分类筛选
        self._filter_var = StringVar(value="全部")
        filter_frame = Frame(left)
        filter_frame.pack(fill=X, pady=2)
        Label(filter_frame, text="筛选:").pack(side=LEFT)
        filter_menu = OptionMenu(filter_frame, self._filter_var, "全部", *CATEGORIES, command=lambda _: self._refresh_char_list())
        filter_menu.pack(side=LEFT, fill=X, expand=True)

        # 搜索框
        self._search_var = StringVar()
        self._search_var.trace_add("write", lambda *_: self._refresh_char_list())
        search = Entry(left, textvariable=self._search_var, width=15)
        search.pack(fill=X, pady=2)
        search.insert(0, "")

        # 字列表
        list_frame = Frame(left)
        list_frame.pack(fill=BOTH, expand=True)
        self._char_listbox = Listbox(list_frame, font=("Consolas", 14), selectmode="single", width=8)
        list_scroll = Scrollbar(list_frame, command=self._char_listbox.yview)
        self._char_listbox.config(yscrollcommand=list_scroll.set)
        self._char_listbox.pack(side=LEFT, fill=BOTH, expand=True)
        list_scroll.pack(side=RIGHT, fill=Y)
        self._char_listbox.bind("<<ListboxSelect>>", self._on_select_char)

        # 添加/删除
        btn_frame = Frame(left)
        btn_frame.pack(fill=X, pady=2)
        Button(btn_frame, text="+", width=3, command=self._add_char).pack(side=LEFT)
        Button(btn_frame, text="-", width=3, command=self._remove_char).pack(side=LEFT, padx=2)

        # 右侧: 详情面板
        right = Frame(self.root)
        right.pack(side=RIGHT, fill=BOTH, expand=True, padx=5, pady=5)

        # ── 顶部: 基本信息 ──
        info_frame = LabelFrame(right, text="基本信息", padx=8, pady=5)
        info_frame.pack(fill=X, pady=(0, 5))

        row1 = Frame(info_frame)
        row1.pack(fill=X, pady=2)
        Label(row1, text="单字:").pack(side=LEFT)
        self._char_var = StringVar()
        self._char_entry = Entry(row1, textvariable=self._char_var, width=4, font=("Consolas", 14))
        self._char_entry.pack(side=LEFT, padx=(2, 10))
        Label(row1, text="名称:").pack(side=LEFT)
        self._name_var = StringVar()
        Entry(row1, textvariable=self._name_var, width=15).pack(side=LEFT, padx=(2, 10))
        Label(row1, text="分类:").pack(side=LEFT)
        self._cat_var = StringVar()
        cat_menu = OptionMenu(row1, self._cat_var, *CATEGORIES)
        cat_menu.pack(side=LEFT, padx=2)
        self._cat_var.trace_add("write", lambda *_: self._on_category_changed())

        Label(row1, text="子类型:").pack(side=LEFT, padx=(10, 0))
        self._subtype_var = StringVar()
        subtypes = ["", "进攻", "防御", "辅助", "双刃剑", "增益", "减益", "消耗", "耐久"]
        sub_menu = OptionMenu(row1, self._subtype_var, *subtypes)
        sub_menu.pack(side=LEFT)

        row1b = Frame(info_frame)
        row1b.pack(fill=X, pady=2)
        self._durable_var = BooleanVar()
        Checkbutton(row1b, text="玩家专属耐久型", variable=self._durable_var).pack(side=LEFT)

        Label(row1b, text="墨水:").pack(side=LEFT, padx=(15, 0))
        self._ink_var = IntVar()
        Entry(row1b, textvariable=self._ink_var, width=4).pack(side=LEFT)
        Label(row1b, text="次数:").pack(side=LEFT, padx=(10, 0))
        self._stack_var = IntVar()
        Entry(row1b, textvariable=self._stack_var, width=4).pack(side=LEFT)
        Label(row1b, text="冷却(s):").pack(side=LEFT, padx=(10, 0))
        self._cd_var = StringVar()
        Entry(row1b, textvariable=self._cd_var, width=6).pack(side=LEFT)

        # ── 属性面板 ──
        prop_frame = LabelFrame(right, text="数值属性", padx=8, pady=5)
        prop_frame.pack(fill=X, pady=(0, 5))

        row2 = Frame(prop_frame)
        row2.pack(fill=X, pady=2)
        Label(row2, text="HP:").pack(side=LEFT)
        self._hp_var = IntVar()
        Entry(row2, textvariable=self._hp_var, width=5).pack(side=LEFT, padx=(2, 8))
        Label(row2, text="伤害:").pack(side=LEFT)
        self._dmg_var = IntVar()
        Entry(row2, textvariable=self._dmg_var, width=5).pack(side=LEFT, padx=(2, 8))
        Label(row2, text="移速:").pack(side=LEFT)
        self._spd_var = IntVar()
        Entry(row2, textvariable=self._spd_var, width=5).pack(side=LEFT, padx=(2, 8))
        Label(row2, text="持续(s):").pack(side=LEFT)
        self._dur_var = StringVar()
        Entry(row2, textvariable=self._dur_var, width=6).pack(side=LEFT, padx=(2, 8))
        Label(row2, text="范围:").pack(side=LEFT)
        self._rng_var = StringVar()
        Entry(row2, textvariable=self._rng_var, width=12).pack(side=LEFT)
        self._dir_var = BooleanVar()
        Checkbutton(row2, text="方向性", variable=self._dir_var).pack(side=LEFT, padx=(10, 0))

        # 效果 & 特殊能力
        row3 = Frame(prop_frame)
        row3.pack(fill=X, pady=2)
        Label(row3, text="效果:").pack(side=LEFT)
        self._effect_var = StringVar()
        Entry(row3, textvariable=self._effect_var, width=40).pack(side=LEFT, padx=(2, 8), fill=X, expand=True)
        Label(row3, text="特殊能力:").pack(side=LEFT, padx=(5, 0))
        self._special_var = StringVar()
        Entry(row3, textvariable=self._special_var, width=40).pack(side=LEFT, padx=(2, 0), fill=X, expand=True)

        # 描述
        Label(prop_frame, text="描述:").pack(anchor=W)
        self._desc_text = Text(prop_frame, height=2, width=80)
        self._desc_text.pack(fill=X)

        # 保存按钮
        save_frame = Frame(right)
        save_frame.pack(fill=X, pady=3)
        Button(save_frame, text="保存修改", bg="#4CAF50", fg="white", command=self._save_current).pack(side=LEFT, padx=2)
        Button(save_frame, text="应用并刷新列表", command=self._refresh_char_list).pack(side=LEFT, padx=2)

        # ── 交互矩阵面板 ──
        inter_frame = LabelFrame(right, text="交互矩阵", padx=5, pady=5)
        inter_frame.pack(fill=BOTH, expand=True, pady=(5, 0))

        inter_top = Frame(inter_frame)
        inter_top.pack(fill=X, pady=(0, 3))
        Label(inter_top, text="作用方:").pack(side=LEFT)
        self._inter_src = StringVar()
        src_chars = sorted(set(w.char for w in self.data.words))
        self._inter_src_menu = OptionMenu(inter_top, self._inter_src, *src_chars if src_chars else ["(无)"])
        self._inter_src_menu.pack(side=LEFT, padx=2)
        self._inter_src.trace_add("write", lambda *_: self._refresh_inter_matrix())

        # 交互矩阵表格 (用 Treeview)
        tree_frame = Frame(inter_frame)
        tree_frame.pack(fill=BOTH, expand=True)

        self._inter_tree = ttk.Treeview(tree_frame, show="headings", height=8)
        tree_scroll_y = Scrollbar(tree_frame, orient=VERTICAL, command=self._inter_tree.yview)
        tree_scroll_x = Scrollbar(tree_frame, orient=HORIZONTAL, command=self._inter_tree.xview)
        self._inter_tree.config(yscrollcommand=tree_scroll_y.set, xscrollcommand=tree_scroll_x.set)

        self._inter_tree.grid(row=0, column=0, sticky="nsew")
        tree_scroll_y.grid(row=0, column=1, sticky="ns")
        tree_scroll_x.grid(row=1, column=0, sticky="ew")
        tree_frame.grid_rowconfigure(0, weight=1)
        tree_frame.grid_columnconfigure(0, weight=1)

        self._inter_tree.bind("<Double-1>", self._on_inter_edit)

        # ── 底部: 工具栏 ──
        bottom = Frame(self.root)
        bottom.pack(side=BOTTOM, fill=X, padx=5, pady=3)
        Button(bottom, text="加载 JSON", command=self._load_json).pack(side=LEFT, padx=2)
        Button(bottom, text="保存 JSON", command=self._save_json).pack(side=LEFT, padx=2)
        Button(bottom, text="导出 Markdown", command=self._export_md).pack(side=LEFT, padx=2)
        Button(bottom, text="加载 Markdown", command=self._load_md).pack(side=LEFT, padx=2)
        Button(bottom, text="快速设置交互", command=self._quick_interact).pack(side=LEFT, padx=2)

    # ── 列表操作 ──

    def _refresh_char_list(self):
        self._char_listbox.delete(0, END)
        filter_cat = self._filter_var.get()
        search = self._search_var.get().strip()

        for w in self.data.words:
            if filter_cat != "全部" and w.category != filter_cat:
                continue
            if search and search not in w.char and search not in w.name:
                continue
            color = CATEGORY_COLORS.get(w.category, "#333")
            tag = "durable" if w.is_durable else "consumable"
            self._char_listbox.insert(END, f" {w.char}  {w.name}")
            idx = self._char_listbox.size() - 1
            self._char_listbox.itemconfig(idx, fg=color)

        # 刷新 src 下拉菜单
        if hasattr(self, '_inter_src_menu'):
            self._inter_src_menu["menu"].delete(0, END)
            for c in sorted(set(w.char for w in self.data.words)):
                self._inter_src_menu["menu"].add_command(label=c, command=lambda v=c: self._inter_src.set(v))

    def _on_select_char(self, event=None):
        sel = self._char_listbox.curselection()
        if not sel:
            return
        idx = sel[0]
        # 获取实际字符
        display = self._char_listbox.get(idx).strip()
        char = display.split()[0] if display else ""
        w = self.data.get_word(char)
        if not w:
            return
        self.current_char = w.char
        self._char_var.set(w.char)
        self._name_var.set(w.name)
        self._cat_var.set(w.category)
        self._subtype_var.set(w.subtype)
        self._durable_var.set(w.is_durable)
        self._ink_var.set(w.ink_cost)
        self._stack_var.set(w.stack)
        self._cd_var.set(str(w.cooldown) if w.cooldown else "")
        self._hp_var.set(w.hp)
        self._dmg_var.set(w.damage)
        self._spd_var.set(w.speed)
        self._dur_var.set(str(w.duration) if w.duration else "")
        self._rng_var.set(w.range_val)
        self._dir_var.set(w.directional)
        self._effect_var.set(w.effect)
        self._special_var.set(w.special)
        self._desc_text.delete("1.0", END)
        self._desc_text.insert("1.0", w.description)

    def _save_current(self):
        if not self.current_char:
            return
        w = self.data.get_word(self.current_char)
        if not w:
            return
        w.char = self._char_var.get().strip() or w.char
        w.name = self._name_var.get().strip()
        w.category = self._cat_var.get()
        w.subtype = self._subtype_var.get()
        w.is_durable = self._durable_var.get()
        w.ink_cost = self._ink_var.get()
        w.stack = self._stack_var.get()
        try:
            w.cooldown = float(self._cd_var.get()) if self._cd_var.get() else 0.0
        except ValueError:
            pass
        w.hp = self._hp_var.get()
        w.damage = self._dmg_var.get()
        w.speed = self._spd_var.get()
        try:
            w.duration = float(self._dur_var.get()) if self._dur_var.get() else 0.0
        except ValueError:
            pass
        w.range_val = self._rng_var.get().strip()
        w.directional = self._dir_var.get()
        w.effect = self._effect_var.get().strip()
        w.special = self._special_var.get().strip()
        w.description = self._desc_text.get("1.0", END).strip()
        self._refresh_char_list()

    def _add_char(self):
        d = Toplevel(self.root)
        d.title("添加新单字")
        d.geometry("300x150")
        Label(d, text="输入单字:").pack(pady=5)
        e = Entry(d, font=("Consolas", 16), width=4)
        e.pack()
        e.focus_set()

        def do_add():
            char = e.get().strip()
            if not char:
                return
            if self.data.get_word(char):
                messagebox.showwarning("警告", f"'{char}' 已存在")
                return
            cat = self._filter_var.get()
            if cat == "全部":
                cat = "召唤"
            self.data.words.append(WordData(char=char, name=f"文字{char}", category=cat))
            self._refresh_char_list()
            d.destroy()

        Button(d, text="添加", command=do_add).pack(pady=5)

    def _remove_char(self):
        if not self.current_char:
            return
        if not messagebox.askyesno("确认", f"删除 '{self.current_char}'？"):
            return
        self.data.words = [w for w in self.data.words if w.char != self.current_char]
        self.current_char = None
        self._refresh_char_list()

    def _on_category_changed(self):
        if self.current_char:
            w = self.data.get_word(self.current_char)
            if w:
                w.category = self._cat_var.get()

    # ── 交互矩阵 ──

    def _refresh_inter_matrix(self):
        tree = self._inter_tree
        tree.delete(*tree.get_children())

        src = self._inter_src.get()
        if not src:
            return

        chars = sorted(set(w.char for w in self.data.words))
        tree["columns"] = ["目标"] + chars
        tree.column("目标", width=50, minwidth=50)
        for c in chars:
            tree.column(c, width=80, minwidth=60, anchor="center")
            tree.heading(c, text=c, anchor="center")
        tree.heading("目标", text="目标")

        for tgt in chars:
            if tgt == src:
                tree.insert("", END, values=[tgt] + ["-"] * len(chars))
                continue
            val = self.data.interactions.get(src, {}).get(tgt, "无效")
            row = [tgt]
            for c in chars:
                if c == tgt:
                    row.append(val)
                elif c == src:
                    row.append("-")
                else:
                    row.append(self.data.interactions.get(c, {}).get(tgt, "无效"))
            tree.insert("", END, values=row)

    def _on_inter_edit(self, event):
        tree = self._inter_tree
        item = tree.identify_row(event.y)
        col = tree.identify_column(event.x)
        if not item or not col or col == "#1":
            return

        col_idx = int(col.replace("#", "")) - 1
        values = list(tree.item(item, "values"))
        tgt_char = values[0]
        src_char = self._inter_src.get()
        if not src_char or tgt_char == src_char:
            return

        current = values[col_idx] if col_idx < len(values) else "无效"

        # 弹出编辑窗口
        d = Toplevel(self.root)
        d.title(f"编辑交互: {src_char} → {tgt_char}")
        d.geometry("300x120")
        Label(d, text=f"{src_char} 对 {tgt_char}:").pack(pady=5)
        var = StringVar(value=current)
        OptionMenu(d, var, *INTERACTION_EFFECTS).pack(pady=5)

        def apply():
            effect = var.get()
            self.data.interactions.setdefault(src_char, {})[tgt_char] = effect
            self._refresh_inter_matrix()
            d.destroy()

        Button(d, text="应用", command=apply).pack(pady=5)

    # ── 文件操作 ──

    def _load_json(self):
        path = filedialog.askopenfilename(
            title="加载 JSON",
            filetypes=[("JSON", "*.json"), ("All", "*.*")],
            initialdir=str(Path(__file__).resolve().parent.parent / "Docs"),
        )
        if path:
            self.data.load_json(path)
            self._refresh_char_list()
            messagebox.showinfo("成功", f"已加载 {len(self.data.words)} 个单字")

    def _save_json(self):
        path = filedialog.asksaveasfilename(
            title="保存 JSON",
            defaultextension=".json",
            filetypes=[("JSON", "*.json")],
            initialdir=str(Path(__file__).resolve().parent.parent / "Docs"),
            initialfile="word_design.json",
        )
        if path:
            self.data.save_json(path)
            messagebox.showinfo("成功", f"已保存到 {path}")

    def _export_md(self):
        path = filedialog.asksaveasfilename(
            title="导出 Markdown",
            defaultextension=".md",
            filetypes=[("Markdown", "*.md")],
            initialdir=str(Path(__file__).resolve().parent.parent / "Docs"),
            initialfile="单字设计与交互矩阵.md",
        )
        if path:
            md = self.data.to_markdown()
            Path(path).write_text(md, encoding="utf-8")
            messagebox.showinfo("成功", f"已导出到 {path}")

    def _load_md(self):
        path = filedialog.askopenfilename(
            title="加载 Markdown",
            filetypes=[("Markdown", "*.md")],
            initialdir=str(Path(__file__).resolve().parent.parent / "Docs"),
        )
        if path:
            self._parse_md(Path(path).read_text(encoding="utf-8"))
            self._refresh_char_list()
            messagebox.showinfo("成功", f"已从 Markdown 加载 {len(self.data.words)} 个单字")

    def _parse_md(self, text: str):
        """简易 Markdown 解析，提取表格中的单字数据"""
        import re
        self.data.words.clear()
        self.data.interactions.clear()

        current_cat = ""
        lines = text.split("\n")
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            # 检测章节标题
            if "召唤类" in line:
                current_cat = "召唤"
            elif "强化类" in line:
                current_cat = "强化"
            elif "防御类" in line:
                current_cat = "防御"
            elif "辅助类" in line:
                current_cat = "辅助"
            elif "建造类" in line:
                current_cat = "建造"
            elif "反应类" in line:
                current_cat = "反应"

            # 检测表格行
            if line.startswith("|") and current_cat:
                cells = [c.strip() for c in line.split("|")[1:-1]]
                if len(cells) >= 2 and cells[0] and cells[0] not in ("---", "作用方", "单字", "**作用方"):
                    # 检查是否是数据行（不是表头分隔符）
                    char = cells[0].replace("**", "").strip()
                    if len(char) == 1 and char in ALL_CHARS:
                        w = self.data.get_word(char)
                        if not w:
                            w = WordData(char=char, category=current_cat)
                            self.data.words.append(w)
                        w.name = cells[1] if len(cells) > 1 else ""
                        # 尝试解析数值
                        for cell in cells[2:]:
                            if cell.isdigit() and w.hp == 0:
                                w.hp = int(cell)
                            elif cell.replace("%", "").isdigit() and w.damage == 0:
                                w.damage = int(cell.replace("%", ""))
            i += 1

    def _quick_interact(self):
        """快速设置批量交互"""
        d = Toplevel(self.root)
        d.title("快速设置交互")
        d.geometry("500x400")

        Label(d, text="选择作用方:").pack(anchor=W, padx=10, pady=(10, 0))
        src_var = StringVar()
        src_chars = sorted(set(w.char for w in self.data.words))
        OptionMenu(d, src_var, *src_chars).pack(fill=X, padx=10)

        Label(d, text="选择承受方 (可多选):").pack(anchor=W, padx=10, pady=(10, 0))
        tgt_frame = Frame(d)
        tgt_frame.pack(fill=BOTH, expand=True, padx=10)
        tgt_listbox = Listbox(tgt_frame, selectmode="multiple", height=10)
        for c in src_chars:
            tgt_listbox.insert(END, c)
        tgt_listbox.pack(fill=BOTH, expand=True)

        Label(d, text="交互效果:").pack(anchor=W, padx=10, pady=(5, 0))
        eff_var = StringVar(value="无效")
        OptionMenu(d, eff_var, *INTERACTION_EFFECTS).pack(fill=X, padx=10)

        def apply_batch():
            src = src_var.get()
            if not src:
                return
            sel = tgt_listbox.curselection()
            effect = eff_var.get()
            for idx in sel:
                tgt = tgt_listbox.get(idx)
                if tgt != src:
                    self.data.interactions.setdefault(src, {})[tgt] = effect
            self._refresh_inter_matrix()
            d.destroy()

        Button(d, text="批量应用", bg="#4CAF50", fg="white", command=apply_batch).pack(pady=10)


# ── 启动 ──────────────────────────────────────────────────────────

def main():
    root = Tk()
    app = WordDesignerApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()