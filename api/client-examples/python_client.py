#!/usr/bin/env python3
"""
University LaTeX API Python クライアントの例

このスクリプトは、University LaTeX APIの基本的な使用方法を示しています。
プロジェクトの作成、コンパイル、品質チェックまでの一連の流れを自動化します。
"""

import requests
import json
import time
from typing import Dict, Any, Optional


class LatexApiClient:
    """University LaTeX API のクライアントクラス"""
    
    def __init__(self, base_url: str = "http://localhost:5000/api"):
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()
    
    def _request(self, method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
        """HTTP リクエストのヘルパーメソッド"""
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        
        try:
            response = self.session.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"リクエストエラー: {e}")
            if hasattr(e.response, 'text'):
                print(f"レスポンス: {e.response.text}")
            raise
    
    def health_check(self) -> Dict[str, Any]:
        """ヘルスチェック"""
        return self._request("GET", "/health")
    
    def get_templates(self) -> Dict[str, Any]:
        """テンプレート一覧の取得"""
        return self._request("GET", "/templates")
    
    def get_template_content(self, template_name: str) -> Dict[str, Any]:
        """特定のテンプレート内容の取得"""
        return self._request("GET", f"/templates/{template_name}")
    
    def create_project(self, semester: str, course: str, report_name: str, 
                      template: Optional[str] = None) -> Dict[str, Any]:
        """プロジェクトの作成"""
        data = {
            "semester": semester,
            "course": course,
            "report_name": report_name
        }
        if template:
            data["template"] = template
        
        return self._request("POST", "/projects", json=data)
    
    def list_projects(self) -> Dict[str, Any]:
        """プロジェクト一覧の取得"""
        return self._request("GET", "/projects")
    
    def compile_document(self, file_path: str, compiler: str = "lualatex",
                        use_bibtex: bool = False, quick: bool = False) -> Dict[str, Any]:
        """文書のコンパイル"""
        data = {
            "file_path": file_path,
            "compiler": compiler,
            "use_bibtex": use_bibtex,
            "quick": quick
        }
        return self._request("POST", "/compile", json=data)
    
    def quality_check(self, file_path: str) -> Dict[str, Any]:
        """品質チェック"""
        data = {"file_path": file_path}
        return self._request("POST", "/quality-check", json=data)
    
    def get_file_content(self, file_path: str) -> Dict[str, Any]:
        """ファイル内容の取得"""
        return self._request("GET", f"/files/{file_path}")
    
    def get_system_info(self) -> Dict[str, Any]:
        """システム情報の取得"""
        return self._request("GET", "/system/info")


def main():
    """メイン関数：完全なワークフローの例"""
    
    # APIクライアントの初期化
    client = LatexApiClient()
    
    print("🚀 University LaTeX API クライアント例")
    print("=" * 50)
    
    try:
        # 1. ヘルスチェック
        print("\n1️⃣ ヘルスチェック...")
        health = client.health_check()
        if health["success"]:
            print(f"   ✅ API サーバーが稼働中: {health['data']['version']}")
        else:
            print(f"   ❌ API サーバーに問題があります")
            return
        
        # 2. システム情報の取得
        print("\n2️⃣ システム情報取得...")
        sys_info = client.get_system_info()
        if sys_info["success"]:
            data = sys_info["data"]
            print(f"   📁 プロジェクトルート: {data['project_root']}")
            print(f"   🐳 Docker利用可能: {data['docker_available']}")
            print(f"   🔧 サポートコンパイラ: {', '.join(data['supported_compilers'])}")
        
        # 3. テンプレート一覧の取得
        print("\n3️⃣ テンプレート一覧取得...")
        templates = client.get_templates()
        if templates["success"]:
            print(f"   📝 利用可能テンプレート: {len(templates['data']['templates'])}個")
            for template in templates["data"]["templates"]:
                print(f"      - {template['name']}: {template['description']}")
        
        # 4. 新しいプロジェクトの作成
        print("\n4️⃣ 新しいプロジェクト作成...")
        project_name = f"api-test-{int(time.time())}"
        project = client.create_project(
            semester="2024-fall",
            course="computer-science",
            report_name=project_name,
            template="report-programming.tex"
        )
        
        if project["success"]:
            project_path = project["data"]["project_path"]
            main_tex_path = f"{project_path}/main.tex"
            print(f"   ✅ プロジェクト作成成功: {project_path}")
            print(f"   📄 テンプレート: {project['data']['template_used']}")
        else:
            print(f"   ❌ プロジェクト作成失敗: {project.get('message', 'Unknown error')}")
            return
        
        # 5. 作成したプロジェクトファイルの確認
        print("\n5️⃣ プロジェクトファイル確認...")
        file_content = client.get_file_content(main_tex_path)
        if file_content["success"]:
            data = file_content["data"]
            print(f"   📄 main.tex: {data['lines']}行, {data['size']}バイト")
            print(f"   📅 最終更新: {data['modified']}")
        
        # 6. 文書のコンパイル
        print("\n6️⃣ 文書コンパイル...")
        compile_result = client.compile_document(
            file_path=main_tex_path,
            compiler="lualatex",
            use_bibtex=False,
            quick=False
        )
        
        if compile_result["success"]:
            data = compile_result["data"]
            print(f"   ✅ コンパイル成功")
            print(f"   🔧 コンパイラ: {data['compiler']}")
            if data.get('pdf_info'):
                pdf = data['pdf_info']
                print(f"   📄 PDF生成: {pdf['path']} ({pdf['size_mb']}MB)")
        else:
            print(f"   ❌ コンパイル失敗")
            if compile_result.get('errors'):
                for error in compile_result['errors']:
                    print(f"      エラー: {error}")
        
        # 7. 品質チェック
        print("\n7️⃣ 品質チェック...")
        quality = client.quality_check(main_tex_path)
        if quality["success"]:
            data = quality["data"]
            print(f"   📊 品質スコア: {data['quality_score']}/100")
            print(f"   🏆 品質レベル: {data['quality_level']}")
            print(f"   ❌ エラー: {data['errors']}個")
            print(f"   ⚠️  警告: {data['warnings']}個")
            
            if data.get('suggestions'):
                print("   💡 改善提案:")
                for suggestion in data['suggestions'][:3]:  # 最初の3つのみ表示
                    print(f"      {suggestion}")
        
        # 8. プロジェクト一覧の確認
        print("\n8️⃣ プロジェクト一覧確認...")
        projects = client.list_projects()
        if projects["success"]:
            total = projects["data"]["total_count"]
            print(f"   📂 総プロジェクト数: {total}個")
            
            # 最近のプロジェクトを表示
            recent_projects = sorted(
                projects["data"]["projects"], 
                key=lambda x: x["modified"], 
                reverse=True
            )[:3]
            
            print("   📋 最近のプロジェクト:")
            for proj in recent_projects:
                status = "PDF有" if proj["has_pdf"] else "PDF無"
                print(f"      - {proj['semester']}/{proj['course']}/{proj['name']} ({status})")
        
        print("\n" + "=" * 50)
        print("🎉 全ての処理が完了しました！")
        print(f"   作成されたプロジェクト: {project_path}")
        print(f"   メインファイル: {main_tex_path}")
        
    except Exception as e:
        print(f"\n❌ エラーが発生しました: {e}")


def interactive_demo():
    """対話型デモンストレーション"""
    client = LatexApiClient()
    
    print("🎯 University LaTeX API 対話型デモ")
    print("=" * 40)
    
    while True:
        print("\n選択してください:")
        print("1. ヘルスチェック")
        print("2. テンプレート一覧")
        print("3. プロジェクト作成")
        print("4. プロジェクト一覧")
        print("5. 文書コンパイル")
        print("6. 品質チェック")
        print("7. システム情報")
        print("0. 終了")
        
        choice = input("\n番号を入力: ").strip()
        
        try:
            if choice == "0":
                print("👋 デモを終了します")
                break
            elif choice == "1":
                result = client.health_check()
                print(f"結果: {json.dumps(result, indent=2, ensure_ascii=False)}")
            elif choice == "2":
                result = client.get_templates()
                if result["success"]:
                    for template in result["data"]["templates"]:
                        print(f"- {template['name']}: {template['filename']}")
                else:
                    print(f"エラー: {result}")
            elif choice == "3":
                semester = input("学期 (例: 2024-fall): ")
                course = input("授業名 (例: physics): ")
                name = input("レポート名 (例: experiment1): ")
                template = input("テンプレート (空白でスキップ): ") or None
                
                result = client.create_project(semester, course, name, template)
                print(f"結果: {json.dumps(result, indent=2, ensure_ascii=False)}")
            elif choice == "4":
                result = client.list_projects()
                if result["success"]:
                    print(f"総プロジェクト数: {result['data']['total_count']}")
                    for proj in result["data"]["projects"][:5]:  # 最初の5個のみ表示
                        print(f"- {proj['semester']}/{proj['course']}/{proj['name']}")
            elif choice == "5":
                file_path = input("ファイルパス: ")
                compiler = input("コンパイラ (lualatex): ") or "lualatex"
                result = client.compile_document(file_path, compiler)
                print(f"結果: {result['success']}")
                if not result["success"]:
                    print(f"エラー: {result.get('errors', 'Unknown')}")
            elif choice == "6":
                file_path = input("ファイルパス: ")
                result = client.quality_check(file_path)
                if result["success"]:
                    data = result["data"]
                    print(f"品質スコア: {data['quality_score']}/100")
                    print(f"品質レベル: {data['quality_level']}")
                    print(f"エラー: {data['errors']}個, 警告: {data['warnings']}個")
            elif choice == "7":
                result = client.get_system_info()
                print(f"結果: {json.dumps(result, indent=2, ensure_ascii=False)}")
            else:
                print("無効な選択です")
        except Exception as e:
            print(f"エラー: {e}")


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "demo":
        interactive_demo()
    else:
        main()