#!/usr/bin/env python3
"""
University LaTeX API Server
他のアプリケーションから大学LaTeXシステムを利用できるRESTful API

Features:
- LaTeX compilation with multiple compilers
- Project creation with templates
- Quality checking and analysis
- Template management
- File operations and monitoring
"""

import subprocess
import shutil
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from werkzeug.utils import secure_filename

# プロジェクトルートパスの設定
PROJECT_ROOT = Path(__file__).parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
TEMPLATES_DIR = PROJECT_ROOT / "templates"
COURSES_DIR = PROJECT_ROOT / "courses"

app = Flask(__name__)
CORS(app)

# 設定
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size


@dataclass
class CompilationRequest:
    """コンパイル要求のデータクラス"""
    file_path: str
    compiler: str = "lualatex"
    use_bibtex: bool = False
    quick: bool = False
    open_pdf: bool = False
    watch: bool = False


@dataclass
class ProjectCreationRequest:
    """プロジェクト作成要求のデータクラス"""
    semester: str
    course: str
    report_name: str
    template: Optional[str] = None


@dataclass
class ApiResponse:
    """API応答の標準フォーマット"""
    success: bool
    message: str
    data: Optional[Dict[str, Any]] = None
    errors: Optional[List[str]] = None


def run_command(cmd: List[str], cwd: Optional[str] = None) -> Dict[str, Any]:
    """コマンド実行のヘルパー関数"""
    try:
        # compile.shスクリプトの場合、Docker経由でコンパイルを実行
        if len(cmd) > 0 and "compile.sh" in cmd[0]:
            return run_docker_compilation(cmd, cwd)
        else:
            # その他のコマンドは通常実行
            result = subprocess.run(
                cmd,
                cwd=cwd or PROJECT_ROOT,
                capture_output=True,
                text=True,
                timeout=300  # 5分タイムアウト
            )
            return {
                "success": result.returncode == 0,
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr
            }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "returncode": -1,
            "stdout": "",
            "stderr": "Command timed out after 5 minutes"
        }
    except Exception as e:
        return {
            "success": False,
            "returncode": -1,
            "stdout": "",
            "stderr": str(e)
        }


def run_docker_compilation(original_cmd: List[str], cwd: Optional[str] = None) -> Dict[str, Any]:
    """Docker経由でのコンパイル実行"""
    try:
        # compile.shの引数を解析
        file_path = None
        compiler = "lualatex"
        use_bibtex = False
        quick = False
        
        i = 1  # スクリプト名をスキップ
        while i < len(original_cmd):
            arg = original_cmd[i]
            if arg == "-c" and i + 1 < len(original_cmd):
                compiler = original_cmd[i + 1]
                i += 2
            elif arg == "-b":
                use_bibtex = True
                i += 1
            elif arg == "-q":
                quick = True
                i += 1
            elif not arg.startswith("-"):
                file_path = arg
                i += 1
            else:
                i += 1
        
        if not file_path:
            return {
                "success": False,
                "returncode": 1,
                "stdout": "",
                "stderr": "No file path specified"
            }
        
        # APIサーバーがDockerコンテナ内で実行されているかどうかを判定
        is_in_docker = Path("/app").exists() and str(PROJECT_ROOT).startswith("/app")
        
        if is_in_docker:
            # Dockerコンテナ内での直接コンパイル
            tex_file = PROJECT_ROOT / file_path  
            if not tex_file.exists():
                # /appパスを/workspaceに変換して再試行
                workspace_path = Path(str(tex_file).replace("/app", "/workspace"))
                if workspace_path.exists():
                    tex_file = workspace_path
                else:
                    return {
                        "success": False,
                        "returncode": 1,
                        "stdout": "",
                        "stderr": f"File not found: {file_path}"
                    }
            return run_direct_latex_compilation(tex_file, compiler, use_bibtex, quick)
        else:
            # ホスト環境からDocker経由でコンパイル
            tex_file = PROJECT_ROOT / file_path
            if not tex_file.exists():
                return {
                    "success": False,
                    "returncode": 1,
                    "stdout": "",
                    "stderr": f"File not found: {file_path}"
                }
            
            work_dir = tex_file.parent
            output_dir = work_dir / "output"
            output_dir.mkdir(exist_ok=True)
            
            base_name = tex_file.stem
            
            # Docker経由でのコンパイル
            docker_cmd = [
                "docker", "compose", "run", "--rm",
                "-w", f"/workspace/{work_dir.relative_to(PROJECT_ROOT)}",
                "latex",
                compiler,
                "-interaction=nonstopmode",
                "-halt-on-error",
                f"-output-directory=output",
                tex_file.name
            ]
        
        stdout_lines = []
        stderr_lines = []
        
        # 初回コンパイル
        stdout_lines.append("🔄 Compilation via Docker")
        result1 = subprocess.run(
            docker_cmd,
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=180
        )
        
        stdout_lines.append(result1.stdout)
        if result1.stderr:
            stderr_lines.append(result1.stderr)
        
        if result1.returncode != 0:
            return {
                "success": False,
                "returncode": result1.returncode,
                "stdout": "\n".join(stdout_lines),
                "stderr": "\n".join(stderr_lines)
            }
        
        # BibTeX処理
        if use_bibtex:
            aux_file = output_dir / f"{base_name}.aux"
            if aux_file.exists():
                bibtex_docker_cmd = [
                    "docker", "compose", "run", "--rm",
                    "-w", f"/workspace/{output_dir.relative_to(PROJECT_ROOT)}",
                    "latex",
                    "bibtex", base_name
                ]
                result_bib = subprocess.run(
                    bibtex_docker_cmd,
                    cwd=PROJECT_ROOT,
                    capture_output=True,
                    text=True
                )
                stdout_lines.append(f"BibTeX: {result_bib.stdout}")
                if result_bib.stderr:
                    stderr_lines.append(result_bib.stderr)
                
                # BibTeX後の再コンパイル
                result2 = subprocess.run(
                    docker_cmd,
                    cwd=PROJECT_ROOT,
                    capture_output=True,
                    text=True
                )
                stdout_lines.append(result2.stdout)
                if result2.stderr:
                    stderr_lines.append(result2.stderr)
        
        # クイックモードでなければ2回目のコンパイル
        if not quick:
            result3 = subprocess.run(
                docker_cmd,
                cwd=PROJECT_ROOT,
                capture_output=True,
                text=True
            )
            stdout_lines.append(result3.stdout)
            if result3.stderr:
                stderr_lines.append(result3.stderr)
        
        # PDF生成確認
        pdf_file = output_dir / f"{base_name}.pdf"
        success = pdf_file.exists()
        
        stdout_lines.append(f"✅ Compilation completed, PDF exists: {success}")
        
        return {
            "success": success,
            "returncode": 0 if success else 1,
            "stdout": "\n".join(stdout_lines),
            "stderr": "\n".join(stderr_lines)
        }
        
    except Exception as e:
        return {
            "success": False,
            "returncode": 1,
            "stdout": "",
            "stderr": f"Docker compilation error: {str(e)}"
        }


def run_direct_latex_compilation(tex_file: Path, compiler: str, use_bibtex: bool, quick: bool) -> Dict[str, Any]:
    """APIコンテナ内からlatex-engineコンテナを使用したコンパイル"""
    try:
        work_dir = tex_file.parent
        output_dir = work_dir / "output"
        output_dir.mkdir(exist_ok=True)
        
        base_name = tex_file.stem
        
        # 同じDockerネットワーク内のlatex-engineコンテナでコンパイル
        compile_cmd = [
            "docker", "exec", "api-latex-engine-1",
            compiler,
            "-interaction=nonstopmode",
            "-halt-on-error",
            f"-output-directory=/workspace/{output_dir.relative_to(Path('/app'))}",
            f"/workspace/{tex_file.relative_to(Path('/app'))}"
        ]
        
        stdout_lines = []
        stderr_lines = []
        
        # 初回コンパイル
        stdout_lines.append("🔄 Compilation via latex-engine container")
        result1 = subprocess.run(
            compile_cmd,
            capture_output=True,
            text=True,
            timeout=180
        )
        
        stdout_lines.append(result1.stdout)
        if result1.stderr:
            stderr_lines.append(result1.stderr)
        
        if result1.returncode != 0:
            return {
                "success": False,
                "returncode": result1.returncode,
                "stdout": "\n".join(stdout_lines),
                "stderr": "\n".join(stderr_lines)
            }
        
        # BibTeX処理
        if use_bibtex:
            aux_file = output_dir / f"{base_name}.aux"
            if aux_file.exists():
                bibtex_cmd = [
                    "docker", "exec", "api-latex-engine-1",
                    "bibtex",
                    f"/workspace/{output_dir.relative_to(Path('/app'))}/{base_name}"
                ]
                result_bib = subprocess.run(
                    bibtex_cmd,
                    capture_output=True,
                    text=True
                )
                stdout_lines.append(f"BibTeX: {result_bib.stdout}")
                if result_bib.stderr:
                    stderr_lines.append(result_bib.stderr)
                
                # BibTeX後の再コンパイル
                result2 = subprocess.run(
                    compile_cmd,
                    capture_output=True,
                    text=True
                )
                stdout_lines.append(result2.stdout)
                if result2.stderr:
                    stderr_lines.append(result2.stderr)
        
        # クイックモードでなければ2回目のコンパイル
        if not quick:
            result3 = subprocess.run(
                compile_cmd,
                capture_output=True,
                text=True
            )
            stdout_lines.append(result3.stdout)
            if result3.stderr:
                stderr_lines.append(result3.stderr)
        
        # PDF生成確認
        pdf_file = output_dir / f"{base_name}.pdf"
        success = pdf_file.exists()
        
        stdout_lines.append(f"✅ Compilation completed, PDF exists: {success}")
        
        return {
            "success": success,
            "returncode": 0 if success else 1,
            "stdout": "\n".join(stdout_lines),
            "stderr": "\n".join(stderr_lines)
        }
        
    except Exception as e:
        return {
            "success": False,
            "returncode": 1,
            "stdout": "",
            "stderr": f"Direct compilation error: {str(e)}"
        }


@app.route('/api/health', methods=['GET'])
def health_check():
    """ヘルスチェックエンドポイント"""
    return jsonify(asdict(ApiResponse(
        success=True,
        message="API server is running",
        data={
            "version": "1.0.0",
            "timestamp": datetime.now().isoformat(),
            "project_root": str(PROJECT_ROOT)
        }
    )))


@app.route('/api/templates', methods=['GET'])
def get_templates():
    """利用可能なテンプレート一覧を取得"""
    try:
        templates = []
        template_descriptions = {
            "report-basic.tex": {
                "name": "基本レポート",
                "description": "一般的な学術レポート用テンプレート",
                "use_case": "授業レポート、課題提出用"
            },
            "report-experiment.tex": {
                "name": "実験レポート",
                "description": "実験・データ分析用テンプレート",
                "use_case": "実験結果報告、データ分析レポート"
            },
            "report-programming.tex": {
                "name": "プログラミングレポート",
                "description": "コード・アルゴリズム用テンプレート",
                "use_case": "プログラミング課題、アルゴリズム解析"
            },
            "thesis.tex": {
                "name": "論文テンプレート",
                "description": "学位論文用テンプレート",
                "use_case": "卒業論文、修士論文、博士論文"
            },
            "presentation-beamer.tex": {
                "name": "プレゼンテーション",
                "description": "Beamer発表スライド用テンプレート",
                "use_case": "学会発表、授業発表、研究発表"
            }
        }
        
        for template_file in TEMPLATES_DIR.glob("*.tex"):
            template_info = template_descriptions.get(template_file.name, {
                "name": template_file.stem,
                "description": "カスタムテンプレート",
                "use_case": "特定用途"
            })
            
            template_info["filename"] = template_file.name
            template_info["path"] = str(template_file.relative_to(PROJECT_ROOT))
            template_info["size"] = template_file.stat().st_size
            template_info["modified"] = datetime.fromtimestamp(
                template_file.stat().st_mtime
            ).isoformat()
            
            templates.append(template_info)
        
        return jsonify(asdict(ApiResponse(
            success=True,
            message="Templates retrieved successfully",
            data={"templates": templates}
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Failed to retrieve templates",
            errors=[str(e)]
        ))), 500


@app.route('/api/templates/<template_name>', methods=['GET'])
def get_template_content(template_name: str):
    """特定のテンプレートの内容を取得"""
    try:
        template_file = TEMPLATES_DIR / secure_filename(template_name)
        if not template_file.exists():
            return jsonify(asdict(ApiResponse(
                success=False,
                message=f"Template not found: {template_name}",
                errors=[f"Template file does not exist: {template_name}"]
            ))), 404
        
        content = template_file.read_text(encoding='utf-8')
        
        return jsonify(asdict(ApiResponse(
            success=True,
            message="Template content retrieved successfully",
            data={
                "filename": template_name,
                "content": content,
                "size": len(content.encode('utf-8')),
                "lines": len(content.splitlines())
            }
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Failed to retrieve template content",
            errors=[str(e)]
        ))), 500


@app.route('/api/projects', methods=['POST'])
def create_project():
    """新しいプロジェクトを作成"""
    try:
        data = request.get_json()
        if not data:
            return jsonify(asdict(ApiResponse(
                success=False,
                message="Request data is required",
                errors=["No JSON data provided"]
            ))), 400
        
        # 必須フィールドのチェック
        required_fields = ['semester', 'course', 'report_name']
        missing_fields = [field for field in required_fields if not data.get(field)]
        if missing_fields:
            return jsonify(asdict(ApiResponse(
                success=False,
                message="Missing required fields",
                errors=[f"Missing field: {field}" for field in missing_fields]
            ))), 400
        
        req = ProjectCreationRequest(
            semester=data['semester'],
            course=data['course'],
            report_name=data['report_name'],
            template=data.get('template')
        )
        
        # プロジェクトディレクトリの作成
        project_path = COURSES_DIR / req.semester / req.course / req.report_name
        project_path.mkdir(parents=True, exist_ok=True)
        
        # サブディレクトリの作成
        for subdir in ['figures', 'output', 'sections']:
            (project_path / subdir).mkdir(exist_ok=True)
            
        # .gitkeep ファイルの作成
        for subdir in ['output', 'figures']:
            (project_path / subdir / '.gitkeep').touch()
        
        # テンプレートのコピーまたはベーステンプレートの作成
        main_tex_path = project_path / 'main.tex'
        
        if req.template and (TEMPLATES_DIR / req.template).exists():
            shutil.copy2(TEMPLATES_DIR / req.template, main_tex_path)
            template_used = req.template
        else:
            # ベーステンプレートを作成
            base_template = """\\documentclass[12pt,a4paper]{ltjsarticle}

% 日本語フォント設定（LuaLaTeX用）
\\usepackage{luatexja-fontspec}
% \\setmainjfont{Noto Serif CJK JP}  % 必要に応じてコメントアウトを外す

% 基本パッケージ
\\usepackage{amsmath,amssymb}
\\usepackage{graphicx}
\\usepackage{hyperref}
\\usepackage{listings}

% 文書情報
\\title{レポートタイトル}
\\author{学籍番号: \\\\ 氏名: }
\\date{\\today}

\\begin{document}

\\maketitle

\\section{はじめに}


\\section{内容}


\\section{まとめ}


% 参考文献
% \\bibliographystyle{plain}
% \\bibliography{../../../common/bibliography}

\\end{document}
"""
            main_tex_path.write_text(base_template, encoding='utf-8')
            template_used = "base template"
        
        # README.mdの作成
        readme_content = f"""# {req.course} - {req.report_name}

## レポート情報
- 学期: {req.semester}
- 授業: {req.course}
- 作成日: {datetime.now().strftime('%Y-%m-%d')}

## コンパイル方法
```bash
# API経由でコンパイル
curl -X POST http://localhost:5000/api/compile \\
  -H "Content-Type: application/json" \\
  -d '{{"file_path": "courses/{req.semester}/{req.course}/{req.report_name}/main.tex"}}'

# スクリプト経由でコンパイル
./scripts/compile.sh courses/{req.semester}/{req.course}/{req.report_name}/main.tex

# BibTeXを使用する場合
./scripts/compile.sh courses/{req.semester}/{req.course}/{req.report_name}/main.tex -b
```

## メモ
- 

"""
        (project_path / 'README.md').write_text(readme_content, encoding='utf-8')
        
        # .gitignoreの作成
        gitignore_content = """output/*
!output/.gitkeep
*.aux
*.log
*.toc
*.lof
*.lot
*.bbl
*.blg
*.out
*.synctex.gz
"""
        (project_path / '.gitignore').write_text(gitignore_content, encoding='utf-8')
        
        return jsonify(asdict(ApiResponse(
            success=True,
            message="Project created successfully",
            data={
                "project_path": str(project_path.relative_to(PROJECT_ROOT)),
                "absolute_path": str(project_path),
                "template_used": template_used,
                "created_files": [
                    "main.tex",
                    "README.md",
                    ".gitignore",
                    "output/.gitkeep",
                    "figures/.gitkeep"
                ]
            }
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Failed to create project",
            errors=[str(e)]
        ))), 500


@app.route('/api/compile', methods=['POST'])
def compile_document():
    """LaTeX文書をコンパイル"""
    try:
        data = request.get_json()
        if not data or not data.get('file_path'):
            return jsonify(asdict(ApiResponse(
                success=False,
                message="file_path is required",
                errors=["No file_path provided in request"]
            ))), 400
        
        req = CompilationRequest(
            file_path=data['file_path'],
            compiler=data.get('compiler', 'lualatex'),
            use_bibtex=data.get('use_bibtex', False),
            quick=data.get('quick', False),
            open_pdf=data.get('open_pdf', False),
            watch=data.get('watch', False)
        )
        
        # ファイル存在チェック
        file_path = PROJECT_ROOT / req.file_path
        if not file_path.exists():
            return jsonify(asdict(ApiResponse(
                success=False,
                message="File not found",
                errors=[f"File does not exist: {req.file_path}"]
            ))), 404
        
        # コンパイルコマンドの構築
        cmd = [str(SCRIPTS_DIR / "compile.sh"), req.file_path]
        
        if req.compiler != "lualatex":
            cmd.extend(["-c", req.compiler])
        if req.use_bibtex:
            cmd.append("-b")
        if req.quick:
            cmd.append("-q")
        if req.open_pdf and not req.watch:  # watchモードではopen_pdfは無効
            cmd.append("-o")
        
        # watchモードは非同期処理が必要なため、通常のAPIでは無効化
        if req.watch:
            return jsonify(asdict(ApiResponse(
                success=False,
                message="Watch mode not supported in API",
                errors=["Use the watch endpoint for file monitoring"]
            ))), 400
        
        # コンパイル実行
        result = run_command(cmd)
        
        # 出力PDFファイルの情報を取得
        pdf_info = None
        pdf_path = file_path.parent / "output" / f"{file_path.stem}.pdf"
        if pdf_path.exists():
            stat = pdf_path.stat()
            pdf_info = {
                "path": str(pdf_path.relative_to(PROJECT_ROOT)),
                "size": stat.st_size,
                "size_mb": round(stat.st_size / (1024 * 1024), 2),
                "created": datetime.fromtimestamp(stat.st_mtime).isoformat()
            }
        
        # ログファイルからエラー詳細を取得
        log_info = None
        log_path = file_path.parent / "output" / f"{file_path.stem}.log"
        if log_path.exists() and not result["success"]:
            try:
                log_content = log_path.read_text(encoding='utf-8', errors='ignore')
                # エラー行を抽出
                error_lines = []
                for line in log_content.split('\n'):
                    if line.startswith('!') or 'Error' in line or 'error' in line.lower():
                        error_lines.append(line.strip())
                
                log_info = {
                    "path": str(log_path.relative_to(PROJECT_ROOT)),
                    "size": log_path.stat().st_size,
                    "error_lines": error_lines[:10]  # 最初の10個のエラー行のみ
                }
            except Exception:
                pass  # ログファイル読み取りエラーは無視
        
        # エラー情報の構築
        errors = []
        if not result["success"]:
            if result["stderr"]:
                errors.append(f"STDERR: {result['stderr']}")
            if log_info and log_info["error_lines"]:
                errors.extend([f"LOG: {line}" for line in log_info["error_lines"][:3]])
            if not errors:
                errors.append("Compilation failed with unknown error")
        
        return jsonify(asdict(ApiResponse(
            success=result["success"],
            message="Compilation completed" if result["success"] else "Compilation failed",
            data={
                "command": " ".join(cmd),
                "returncode": result["returncode"],
                "compiler": req.compiler,
                "used_bibtex": req.use_bibtex,
                "quick_mode": req.quick,
                "stdout": result["stdout"],
                "stderr": result["stderr"],
                "pdf_info": pdf_info,
                "log_info": log_info
            },
            errors=errors if errors else None
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Compilation request failed",
            errors=[str(e)]
        ))), 500


@app.route('/api/quality-check', methods=['POST'])
def quality_check():
    """文書の品質チェック"""
    try:
        data = request.get_json()
        if not data or not data.get('file_path'):
            return jsonify(asdict(ApiResponse(
                success=False,
                message="file_path is required",
                errors=["No file_path provided in request"]
            ))), 400
        
        file_path = data['file_path']
        full_path = PROJECT_ROOT / file_path
        
        if not full_path.exists():
            return jsonify(asdict(ApiResponse(
                success=False,
                message="File not found",
                errors=[f"File does not exist: {file_path}"]
            ))), 404
        
        # 品質チェックスクリプトの実行
        cmd = [str(SCRIPTS_DIR / "check-quality.sh"), file_path]
        result = run_command(cmd)
        
        # 出力の解析（簡易版）
        output_lines = result["stdout"].split('\n')
        errors = 0
        warnings = 0
        suggestions = []
        
        for line in output_lines:
            if "❌ エラー:" in line:
                try:
                    errors = int(line.split("❌ エラー:")[1].split("個")[0].strip())
                except:
                    pass
            elif "⚠️  警告:" in line:
                try:
                    warnings = int(line.split("⚠️  警告:")[1].split("個")[0].strip())
                except:
                    pass
            elif line.strip().startswith(("1.", "2.", "3.", "4.", "5.")):
                suggestions.append(line.strip())
        
        quality_score = max(0, 100 - (errors * 20) - (warnings * 5))
        quality_level = "excellent" if quality_score >= 90 else \
                       "good" if quality_score >= 70 else \
                       "needs_improvement" if quality_score >= 50 else "poor"
        
        return jsonify(asdict(ApiResponse(
            success=True,
            message="Quality check completed",
            data={
                "file_path": file_path,
                "quality_score": quality_score,
                "quality_level": quality_level,
                "errors": errors,
                "warnings": warnings,
                "suggestions": suggestions,
                "full_output": result["stdout"],
                "check_successful": result["success"]
            }
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Quality check failed",
            errors=[str(e)]
        ))), 500


@app.route('/api/files/<path:file_path>', methods=['GET'])
def get_file(file_path: str):
    """ファイル内容の取得"""
    try:
        full_path = PROJECT_ROOT / file_path
        
        if not full_path.exists():
            return jsonify(asdict(ApiResponse(
                success=False,
                message="File not found",
                errors=[f"File does not exist: {file_path}"]
            ))), 404
        
        if full_path.is_dir():
            return jsonify(asdict(ApiResponse(
                success=False,
                message="Path is a directory",
                errors=[f"Path is a directory, not a file: {file_path}"]
            ))), 400
        
        # PDFファイルの場合はバイナリ送信
        if file_path.endswith('.pdf'):
            return send_file(full_path, as_attachment=False, mimetype='application/pdf')
        
        # テキストファイルの場合は内容を返す
        try:
            content = full_path.read_text(encoding='utf-8')
            stat = full_path.stat()
            
            return jsonify(asdict(ApiResponse(
                success=True,
                message="File content retrieved",
                data={
                    "path": file_path,
                    "content": content,
                    "size": stat.st_size,
                    "lines": len(content.splitlines()),
                    "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                    "encoding": "utf-8"
                }
            )))
            
        except UnicodeDecodeError:
            # バイナリファイルの場合
            return send_file(full_path, as_attachment=True)
            
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Failed to retrieve file",
            errors=[str(e)]
        ))), 500


@app.route('/api/projects', methods=['GET'])
def list_projects():
    """プロジェクト一覧の取得"""
    try:
        projects = []
        
        if COURSES_DIR.exists():
            for semester_dir in COURSES_DIR.iterdir():
                if not semester_dir.is_dir():
                    continue
                    
                for course_dir in semester_dir.iterdir():
                    if not course_dir.is_dir():
                        continue
                        
                    for project_dir in course_dir.iterdir():
                        if not project_dir.is_dir():
                            continue
                        
                        main_tex = project_dir / "main.tex"
                        if main_tex.exists():
                            stat = main_tex.stat()
                            pdf_path = project_dir / "output" / f"{main_tex.stem}.pdf"
                            
                            project_info = {
                                "semester": semester_dir.name,
                                "course": course_dir.name,
                                "name": project_dir.name,
                                "path": str(project_dir.relative_to(PROJECT_ROOT)),
                                "main_tex_path": str(main_tex.relative_to(PROJECT_ROOT)),
                                "has_pdf": pdf_path.exists(),
                                "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                                "size": stat.st_size
                            }
                            
                            if pdf_path.exists():
                                pdf_stat = pdf_path.stat()
                                project_info["pdf_info"] = {
                                    "path": str(pdf_path.relative_to(PROJECT_ROOT)),
                                    "size": pdf_stat.st_size,
                                    "created": datetime.fromtimestamp(pdf_stat.st_mtime).isoformat()
                                }
                            
                            projects.append(project_info)
        
        return jsonify(asdict(ApiResponse(
            success=True,
            message="Projects retrieved successfully",
            data={
                "projects": projects,
                "total_count": len(projects)
            }
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Failed to list projects",
            errors=[str(e)]
        ))), 500


@app.route('/api/templates/manage', methods=['POST'])
def manage_templates():
    """テンプレート管理（CLI manage-templates.sh 相当）"""
    try:
        data = request.get_json()
        if not data or not data.get('action'):
            return jsonify(asdict(ApiResponse(
                success=False,
                message="action is required",
                errors=["Action must be specified: list, enable, disable, add, info, validate"]
            ))), 400
        
        action = data['action']
        cmd = [str(SCRIPTS_DIR / "manage-templates.sh"), action]
        
        # 各アクションに応じた引数を追加
        if action in ['enable', 'disable', 'info'] and data.get('template_id'):
            cmd.append(data['template_id'])
        elif action == 'add' and data.get('template_file'):
            cmd.append(data['template_file'])
        elif action == 'list' and data.get('category'):
            cmd.append('--category')
        
        result = run_command(cmd)
        
        return jsonify(asdict(ApiResponse(
            success=result["success"],
            message=f"Template management action '{action}' completed",
            data={
                "action": action,
                "command": " ".join(cmd),
                "output": result["stdout"],
                "stderr": result["stderr"] if result["stderr"] else None
            },
            errors=[result["stderr"]] if not result["success"] and result["stderr"] else None
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Template management failed",
            errors=[str(e)]
        ))), 500


@app.route('/api/projects/<path:project_path>', methods=['DELETE'])
def delete_project(project_path: str):
    """プロジェクトを削除"""
    try:
        full_path = PROJECT_ROOT / project_path
        
        if not full_path.exists():
            return jsonify(asdict(ApiResponse(
                success=False,
                message="Project not found",
                errors=[f"Project does not exist: {project_path}"]
            ))), 404
        
        if not full_path.is_dir():
            return jsonify(asdict(ApiResponse(
                success=False,
                message="Path is not a directory",
                errors=[f"Path is not a project directory: {project_path}"]
            ))), 400
        
        # main.texの存在確認（プロジェクトディレクトリであることの確認）
        main_tex = full_path / "main.tex"
        if not main_tex.exists():
            return jsonify(asdict(ApiResponse(
                success=False,
                message="Invalid project directory",
                errors=[f"Directory does not contain main.tex: {project_path}"]
            ))), 400
        
        # プロジェクトディレクトリを削除
        shutil.rmtree(full_path)
        
        return jsonify(asdict(ApiResponse(
            success=True,
            message="Project deleted successfully",
            data={
                "deleted_path": project_path,
                "absolute_path": str(full_path)
            }
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Failed to delete project",
            errors=[str(e)]
        ))), 500


@app.route('/api/watch', methods=['POST'])
def start_watch():
    """ファイル監視の開始（WebSocket的な用途）"""
    try:
        data = request.get_json()
        if not data or not data.get('file_path'):
            return jsonify(asdict(ApiResponse(
                success=False,
                message="file_path is required",
                errors=["No file_path provided in request"]
            ))), 400
        
        file_path = data['file_path']
        full_path = PROJECT_ROOT / file_path
        
        if not full_path.exists():
            return jsonify(asdict(ApiResponse(
                success=False,
                message="File not found",
                errors=[f"File does not exist: {file_path}"]
            ))), 404
        
        # ファイル監視は長時間実行のため、APIでは基本情報のみ返す
        # 実際の監視は別途WebSocketやSSEで実装する必要がある
        watch_info = {
            "file_path": file_path,
            "absolute_path": str(full_path),
            "status": "watch_ready",
            "message": "File watching requires WebSocket or SSE implementation",
            "last_modified": datetime.fromtimestamp(full_path.stat().st_mtime).isoformat()
        }
        
        return jsonify(asdict(ApiResponse(
            success=True,
            message="Watch mode information retrieved",
            data=watch_info
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Failed to start watch mode",
            errors=[str(e)]
        ))), 500


@app.route('/api/upload', methods=['POST'])
def upload_file():
    """ファイルアップロード"""
    try:
        if 'file' not in request.files:
            return jsonify(asdict(ApiResponse(
                success=False,
                message="No file provided",
                errors=["No file part in the request"]
            ))), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify(asdict(ApiResponse(
                success=False,
                message="No file selected",
                errors=["No file selected for upload"]
            ))), 400
        
        project_path = request.form.get('project_path')
        subdirectory = request.form.get('subdirectory', '')
        
        if not project_path:
            return jsonify(asdict(ApiResponse(
                success=False,
                message="project_path is required",
                errors=["Project path must be specified"]
            ))), 400
        
        # アップロード先ディレクトリの設定
        upload_dir = PROJECT_ROOT / project_path
        if subdirectory:
            upload_dir = upload_dir / subdirectory
        
        if not upload_dir.exists():
            upload_dir.mkdir(parents=True, exist_ok=True)
        
        # ファイル名のセキュリティ処理
        filename = secure_filename(file.filename)
        if not filename:
            filename = "uploaded_file"
        
        file_path = upload_dir / filename
        
        # ファイル保存
        file.save(str(file_path))
        
        file_stat = file_path.stat()
        
        return jsonify(asdict(ApiResponse(
            success=True,
            message="File uploaded successfully",
            data={
                "filename": filename,
                "path": str(file_path.relative_to(PROJECT_ROOT)),
                "absolute_path": str(file_path),
                "size": file_stat.st_size,
                "size_mb": round(file_stat.st_size / (1024 * 1024), 4),
                "uploaded_at": datetime.fromtimestamp(file_stat.st_mtime).isoformat()
            }
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="File upload failed",
            errors=[str(e)]
        ))), 500


@app.route('/api/system/info', methods=['GET'])
def system_info():
    """システム情報の取得"""
    try:
        # Docker環境の確認
        docker_available = shutil.which('docker') is not None
        docker_compose_available = shutil.which('docker-compose') is not None or shutil.which('docker') is not None
        
        # 利用可能なコンパイラ
        compilers = ['lualatex', 'pdflatex', 'xelatex', 'platex']
        
        # ディスク使用量
        total_size = 0
        if COURSES_DIR.exists():
            for file_path in COURSES_DIR.rglob('*'):
                if file_path.is_file():
                    total_size += file_path.stat().st_size
        
        return jsonify(asdict(ApiResponse(
            success=True,
            message="System information retrieved",
            data={
                "project_root": str(PROJECT_ROOT),
                "courses_directory": str(COURSES_DIR),
                "templates_directory": str(TEMPLATES_DIR),
                "scripts_directory": str(SCRIPTS_DIR),
                "docker_available": docker_available,
                "docker_compose_available": docker_compose_available,
                "supported_compilers": compilers,
                "total_project_size_mb": round(total_size / (1024 * 1024), 2),
                "api_version": "1.0.0"
            }
        )))
        
    except Exception as e:
        return jsonify(asdict(ApiResponse(
            success=False,
            message="Failed to retrieve system information",
            errors=[str(e)]
        ))), 500


@app.errorhandler(404)
def not_found(_error):
    return jsonify(asdict(ApiResponse(
        success=False,
        message="Endpoint not found",
        errors=["The requested endpoint does not exist"]
    ))), 404


@app.errorhandler(413)
def too_large(_error):
    return jsonify(asdict(ApiResponse(
        success=False,
        message="File too large",
        errors=["File size exceeds the maximum limit of 16MB"]
    ))), 413


@app.errorhandler(500)
def internal_error(_error):
    return jsonify(asdict(ApiResponse(
        success=False,
        message="Internal server error",
        errors=["An unexpected error occurred"]
    ))), 500


if __name__ == '__main__':
    import os
    
    # 環境変数からの設定取得
    host = os.getenv('LATEX_API_HOST', '0.0.0.0')
    port = int(os.getenv('LATEX_API_PORT', '5000'))
    debug = os.getenv('FLASK_DEBUG', 'true').lower() == 'true'
    
    print(f"University LaTeX API Server")
    print(f"Project Root: {PROJECT_ROOT}")
    print(f"Templates: {len(list(TEMPLATES_DIR.glob('*.tex')))} available")
    print(f"Starting server on http://{host}:{port}")
    print()
    
    app.run(host=host, port=port, debug=debug)