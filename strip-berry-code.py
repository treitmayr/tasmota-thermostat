#!/usr/bin/python

import sys
import re

def extract_newlines(s):
    return re.sub(r'[^\n]+', '', s, flags=re.S)

def tokenize(code):
    token_specification = [
        ('STRING',   r'f?"(?:[^"]|\\")*"|' r"f?'(?:[^']|\\')*'"),
        ('LINECMT',  r'#$|#[^-].*?$'),
        ('MLINECMT', r'#-.*?-#'),
        ('SPC1',     r'[ \t]+$'),
        ('SPC2',     r'^[ \t]+'),
        ('OPSPC1',   r'(?<![\+\*/%\^&|=<>~-])[ \t]+(?=[\+\*/%\^&|=<>~-])'),
        ('OPSPC2',   r'(?<=[\+\*/%\^&|=<>~-])[ \t]+(?![\+\*/%\^&|=<>~-])'),
        ('PARSPC1',   r'[ \t]+(?=[\[\]\(\)\.,!?:])'),
        ('PARSPC2',   r'(?<=[\[\]\(\)\.,!?:])[ \t]+'),
        ('SPC3',     r'[ \t]+'),
        ('CR',       r'\r+'),
        ('REST',     r'.'),
    ]
    tok_regex = '|'.join('(?P<%s>%s)' % pair for pair in token_specification)
    for mo in re.finditer(tok_regex, code, flags=re.S+re.M):
        kind = mo.lastgroup
        value = mo.group()
        #print(f'kind={kind}, value={value}', file=sys.stderr)
        if kind in ('STRING', 'REST'):
            yield value
        elif kind in ('SPC3'):
            yield ' '
        else:
            yield extract_newlines(value)

s = sys.stdin.read()
print(''.join(tokenize(s)), end='')
