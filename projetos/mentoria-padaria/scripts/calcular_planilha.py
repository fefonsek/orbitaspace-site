"""Caso Mentoria: calcula as fórmulas da planilha modelo sem abrir o Excel.

Uso: python calcular_planilha.py <saida.csv> <planilha.xlsx>:<aba>:<ultima_linha> ...

Usa o pycel (pip install pycel), que lê o .xlsx e calcula as fórmulas como o
Excel (SUMIFS, IF, SUM e contas simples). Grava um CSV com o valor calculado
de cada célula da aba de indicadores (colunas A a H, até a última linha), que
scripts/conferir_planilha.R compara com os números da página.
"""
import csv
import sys

from pycel import ExcelCompiler
from openpyxl.utils import get_column_letter


def main() -> None:
    saida = sys.argv[1]
    with open(saida, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["arquivo", "linha", "coluna", "valor"])
        for alvo in sys.argv[2:]:
            arquivo, aba, ultima = alvo.rsplit(":", 2)
            excel = ExcelCompiler(filename=arquivo)
            for linha in range(1, int(ultima) + 1):
                for coluna in range(1, 9):
                    valor = excel.evaluate(f"'{aba}'!{get_column_letter(coluna)}{linha}")
                    w.writerow([arquivo, linha, coluna, "" if valor is None else valor])
            print(f"calculada com pycel: {arquivo}")


if __name__ == "__main__":
    main()
