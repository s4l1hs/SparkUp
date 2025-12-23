from server.app import app

# Otomatik veri yükleme kontrolü
import os
import importlib.util
from sqlmodel import Session, select
from server.db import engine
from server.models import QuizQuestion, DailyInfo

def _auto_seed_if_needed():
	from server.db import create_db_and_tables
	# Önce tabloları oluştur
	create_db_and_tables()
	with Session(engine) as session:
		needs_seed = False
		if not session.exec(select(QuizQuestion)).first():
			needs_seed = True
		if not session.exec(select(DailyInfo)).first():
			needs_seed = True
		# Challenge content removed from backend; no seed check required
		if needs_seed:
			print("[main.py] Otomatik veri yükleme başlatılıyor...")
			# seed_manual.py scriptini import edip çalıştır
			seed_path = os.path.join(os.path.dirname(__file__), "seed_manual.py")
			spec = importlib.util.spec_from_file_location("seed_manual", seed_path)
			seed_mod = importlib.util.module_from_spec(spec)
			spec.loader.exec_module(seed_mod)
			seed_mod.seed_database_manual()

_auto_seed_if_needed()