#!/usr/bin/python

import sys
import re

def extract_newlines(s):
    return re.sub(r'[^\n]+', '', s, flags=re.S)

def remove_spaces(code, keep_lines=True):
    token_specification = [
        ('STRING',   r'f?"(?:[^"]|\\")*"|' r"f?'(?:[^']|\\')*'"),
        ('LINECMT',  r'#$|#[^-].*?$'),
        ('MLINECMT', r'#-.*?-#'),
        ('SPC1',     r'[ \t]+$'),
        ('SPC2',     r'^[ \t]+'),
        ('OPSPC1',   r'(?<![\+\*/%\^&|=<>~-])[ \t]+(?=[\+\*/%\^&|=<>~-])'),
        ('OPSPC2',   r'(?<=[\+\*/%\^&|=<>~-])[ \t]+(?![\+\*/%\^&|=<>~-])'),
        ('PARSPC1',  r'[ \t]+(?=[\[\]\(\)\.,!?:])'),
        ('PARSPC2',  r'(?<=[\[\]\(\)\.,!?:])[ \t]+'),
        ('SPC3',     r'[ \t]+'),
        ('CR',       r'\r+'),
        ('LF',       r'\n+'),
        ('REST',     r'.'),
    ]
    tok_regex = '|'.join('(?P<%s>%s)' % pair for pair in token_specification)
    result_tokens = []
    for mo in re.finditer(tok_regex, code, flags=re.S|re.M):
        kind = mo.lastgroup
        value = mo.group()
        #print(f'kind={kind}, value={value}', file=sys.stderr)
        if kind in ('STRING', 'REST'):
            result_tokens.append(value)
        elif kind in ('SPC3'):
            result_tokens.append(' ')
        elif kind in ('LF'):
            result_tokens.append(value if keep_lines else ' ')
        #else:
        #    print(f"keep_lines={keep_lines}")
        #    result_tokens.append(extract_newlines(value))

    return ''.join(result_tokens)

        # ('KEYWORDS', r'\b(if|elif|else|while|for|def|end|class|break|continue|return|true|false|nil|var|do|import|as|static)\b')
        # ('')
        # ('PROCS',    r'(?i:def')


s = sys.stdin.read()
print(remove_spaces(s, True).rstrip())
