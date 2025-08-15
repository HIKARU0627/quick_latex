#!/usr/bin/env node
/**
 * University LaTeX API JavaScript/Node.js クライアントの例
 * 
 * このスクリプトは、University LaTeX APIの基本的な使用方法を示しています。
 * プロジェクトの作成、コンパイル、品質チェックまでの一連の流れを自動化します。
 */

const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');

class LatexApiClient {
    /**
     * University LaTeX API のクライアントクラス
     * @param {string} baseUrl APIのベースURL
     */
    constructor(baseUrl = 'http://localhost:5000/api') {
        this.baseUrl = baseUrl.replace(/\/$/, '');
        this.client = axios.create({
            baseURL: this.baseUrl,
            timeout: 300000, // 5分タイムアウト
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }

    /**
     * ヘルスチェック
     */
    async healthCheck() {
        try {
            const response = await this.client.get('/health');
            return response.data;
        } catch (error) {
            throw new Error(`Health check failed: ${error.message}`);
        }
    }

    /**
     * テンプレート一覧の取得
     */
    async getTemplates() {
        const response = await this.client.get('/templates');
        return response.data;
    }

    /**
     * 特定のテンプレート内容の取得
     * @param {string} templateName テンプレート名
     */
    async getTemplateContent(templateName) {
        const response = await this.client.get(`/templates/${templateName}`);
        return response.data;
    }

    /**
     * プロジェクトの作成
     * @param {string} semester 学期
     * @param {string} course 授業名
     * @param {string} reportName レポート名
     * @param {string} template テンプレート名（オプション）
     */
    async createProject(semester, course, reportName, template = null) {
        const data = {
            semester,
            course,
            report_name: reportName
        };
        
        if (template) {
            data.template = template;
        }

        const response = await this.client.post('/projects', data);
        return response.data;
    }

    /**
     * プロジェクト一覧の取得
     */
    async listProjects() {
        const response = await this.client.get('/projects');
        return response.data;
    }

    /**
     * 文書のコンパイル
     * @param {string} filePath ファイルパス
     * @param {string} compiler コンパイラ
     * @param {boolean} useBibtex BibTeX使用フラグ
     * @param {boolean} quick クイックモード
     */
    async compileDocument(filePath, compiler = 'lualatex', useBibtex = false, quick = false) {
        const data = {
            file_path: filePath,
            compiler,
            use_bibtex: useBibtex,
            quick
        };

        const response = await this.client.post('/compile', data);
        return response.data;
    }

    /**
     * 品質チェック
     * @param {string} filePath ファイルパス
     */
    async qualityCheck(filePath) {
        const data = { file_path: filePath };
        const response = await this.client.post('/quality-check', data);
        return response.data;
    }

    /**
     * ファイル内容の取得
     * @param {string} filePath ファイルパス
     */
    async getFileContent(filePath) {
        const response = await this.client.get(`/files/${filePath}`);
        return response.data;
    }

    /**
     * システム情報の取得
     */
    async getSystemInfo() {
        const response = await this.client.get('/system/info');
        return response.data;
    }
}

/**
 * メイン関数：完全なワークフローの例
 */
async function main() {
    console.log('🚀 University LaTeX API JavaScript クライアント例');
    console.log('='.repeat(55));

    // APIクライアントの初期化
    const client = new LatexApiClient();

    try {
        // 1. ヘルスチェック
        console.log('\n1️⃣ ヘルスチェック...');
        const health = await client.healthCheck();
        if (health.success) {
            console.log(`   ✅ API サーバーが稼働中: ${health.data.version}`);
        } else {
            console.log('   ❌ API サーバーに問題があります');
            return;
        }

        // 2. システム情報の取得
        console.log('\n2️⃣ システム情報取得...');
        const sysInfo = await client.getSystemInfo();
        if (sysInfo.success) {
            const data = sysInfo.data;
            console.log(`   📁 プロジェクトルート: ${data.project_root}`);
            console.log(`   🐳 Docker利用可能: ${data.docker_available}`);
            console.log(`   🔧 サポートコンパイラ: ${data.supported_compilers.join(', ')}`);
        }

        // 3. テンプレート一覧の取得
        console.log('\n3️⃣ テンプレート一覧取得...');
        const templates = await client.getTemplates();
        if (templates.success) {
            console.log(`   📝 利用可能テンプレート: ${templates.data.templates.length}個`);
            templates.data.templates.forEach(template => {
                console.log(`      - ${template.name}: ${template.description}`);
            });
        }

        // 4. 新しいプロジェクトの作成
        console.log('\n4️⃣ 新しいプロジェクト作成...');
        const projectName = `js-api-test-${Date.now()}`;
        const project = await client.createProject(
            '2024-fall',
            'mathematics',
            projectName,
            'report-basic.tex'
        );

        if (project.success) {
            const projectPath = project.data.project_path;
            const mainTexPath = `${projectPath}/main.tex`;
            console.log(`   ✅ プロジェクト作成成功: ${projectPath}`);
            console.log(`   📄 テンプレート: ${project.data.template_used}`);

            // 5. 作成したプロジェクトファイルの確認
            console.log('\n5️⃣ プロジェクトファイル確認...');
            const fileContent = await client.getFileContent(mainTexPath);
            if (fileContent.success) {
                const data = fileContent.data;
                console.log(`   📄 main.tex: ${data.lines}行, ${data.size}バイト`);
                console.log(`   📅 最終更新: ${data.modified}`);
            }

            // 6. 文書のコンパイル
            console.log('\n6️⃣ 文書コンパイル...');
            const compileResult = await client.compileDocument(
                mainTexPath,
                'lualatex',
                false,
                false
            );

            if (compileResult.success) {
                const data = compileResult.data;
                console.log('   ✅ コンパイル成功');
                console.log(`   🔧 コンパイラ: ${data.compiler}`);
                if (data.pdf_info) {
                    const pdf = data.pdf_info;
                    console.log(`   📄 PDF生成: ${pdf.path} (${pdf.size_mb}MB)`);
                }
            } else {
                console.log('   ❌ コンパイル失敗');
                if (compileResult.errors) {
                    compileResult.errors.forEach(error => {
                        console.log(`      エラー: ${error}`);
                    });
                }
            }

            // 7. 品質チェック
            console.log('\n7️⃣ 品質チェック...');
            const quality = await client.qualityCheck(mainTexPath);
            if (quality.success) {
                const data = quality.data;
                console.log(`   📊 品質スコア: ${data.quality_score}/100`);
                console.log(`   🏆 品質レベル: ${data.quality_level}`);
                console.log(`   ❌ エラー: ${data.errors}個`);
                console.log(`   ⚠️  警告: ${data.warnings}個`);

                if (data.suggestions && data.suggestions.length > 0) {
                    console.log('   💡 改善提案:');
                    data.suggestions.slice(0, 3).forEach(suggestion => {
                        console.log(`      ${suggestion}`);
                    });
                }
            }

            // 8. プロジェクト一覧の確認
            console.log('\n8️⃣ プロジェクト一覧確認...');
            const projects = await client.listProjects();
            if (projects.success) {
                const total = projects.data.total_count;
                console.log(`   📂 総プロジェクト数: ${total}個`);

                // 最近のプロジェクトを表示
                const recentProjects = projects.data.projects
                    .sort((a, b) => new Date(b.modified) - new Date(a.modified))
                    .slice(0, 3);

                console.log('   📋 最近のプロジェクト:');
                recentProjects.forEach(proj => {
                    const status = proj.has_pdf ? 'PDF有' : 'PDF無';
                    console.log(`      - ${proj.semester}/${proj.course}/${proj.name} (${status})`);
                });
            }

            console.log('\n' + '='.repeat(55));
            console.log('🎉 全ての処理が完了しました！');
            console.log(`   作成されたプロジェクト: ${projectPath}`);
            console.log(`   メインファイル: ${mainTexPath}`);

        } else {
            console.log(`   ❌ プロジェクト作成失敗: ${project.message || 'Unknown error'}`);
        }

    } catch (error) {
        console.log(`\n❌ エラーが発生しました: ${error.message}`);
        if (error.response && error.response.data) {
            console.log(`   詳細: ${JSON.stringify(error.response.data, null, 2)}`);
        }
    }
}

/**
 * 対話型デモンストレーション
 */
async function interactiveDemo() {
    const readline = require('readline');
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });

    const question = (prompt) => {
        return new Promise((resolve) => {
            rl.question(prompt, resolve);
        });
    };

    const client = new LatexApiClient();

    console.log('🎯 University LaTeX API 対話型デモ');
    console.log('='.repeat(45));

    try {
        while (true) {
            console.log('\n選択してください:');
            console.log('1. ヘルスチェック');
            console.log('2. テンプレート一覧');
            console.log('3. プロジェクト作成');
            console.log('4. プロジェクト一覧');
            console.log('5. 文書コンパイル');
            console.log('6. 品質チェック');
            console.log('7. システム情報');
            console.log('0. 終了');

            const choice = await question('\n番号を入力: ');

            try {
                if (choice === '0') {
                    console.log('👋 デモを終了します');
                    break;
                } else if (choice === '1') {
                    const result = await client.healthCheck();
                    console.log(`結果: ${JSON.stringify(result, null, 2)}`);
                } else if (choice === '2') {
                    const result = await client.getTemplates();
                    if (result.success) {
                        result.data.templates.forEach(template => {
                            console.log(`- ${template.name}: ${template.filename}`);
                        });
                    } else {
                        console.log(`エラー: ${JSON.stringify(result, null, 2)}`);
                    }
                } else if (choice === '3') {
                    const semester = await question('学期 (例: 2024-fall): ');
                    const course = await question('授業名 (例: physics): ');
                    const name = await question('レポート名 (例: experiment1): ');
                    const template = await question('テンプレート (空白でスキップ): ') || null;

                    const result = await client.createProject(semester, course, name, template);
                    console.log(`結果: ${JSON.stringify(result, null, 2)}`);
                } else if (choice === '4') {
                    const result = await client.listProjects();
                    if (result.success) {
                        console.log(`総プロジェクト数: ${result.data.total_count}`);
                        result.data.projects.slice(0, 5).forEach(proj => {
                            console.log(`- ${proj.semester}/${proj.course}/${proj.name}`);
                        });
                    }
                } else if (choice === '5') {
                    const filePath = await question('ファイルパス: ');
                    const compiler = await question('コンパイラ (lualatex): ') || 'lualatex';
                    const result = await client.compileDocument(filePath, compiler);
                    console.log(`結果: ${result.success}`);
                    if (!result.success) {
                        console.log(`エラー: ${result.errors || 'Unknown'}`);
                    }
                } else if (choice === '6') {
                    const filePath = await question('ファイルパス: ');
                    const result = await client.qualityCheck(filePath);
                    if (result.success) {
                        const data = result.data;
                        console.log(`品質スコア: ${data.quality_score}/100`);
                        console.log(`品質レベル: ${data.quality_level}`);
                        console.log(`エラー: ${data.errors}個, 警告: ${data.warnings}個`);
                    }
                } else if (choice === '7') {
                    const result = await client.getSystemInfo();
                    console.log(`結果: ${JSON.stringify(result, null, 2)}`);
                } else {
                    console.log('無効な選択です');
                }
            } catch (error) {
                console.log(`エラー: ${error.message}`);
            }
        }
    } finally {
        rl.close();
    }
}

/**
 * 使用例の関数集
 */
const examples = {
    /**
     * 基本的な使用例
     */
    async basicUsage() {
        const client = new LatexApiClient();
        
        // プロジェクト作成
        const project = await client.createProject(
            '2024-fall', 
            'physics', 
            'basic-example',
            'report-basic.tex'
        );
        
        if (project.success) {
            const mainTexPath = project.data.project_path + '/main.tex';
            
            // コンパイル
            const compile = await client.compileDocument(mainTexPath);
            
            if (compile.success) {
                console.log('✅ コンパイル成功');
                
                // 品質チェック
                const quality = await client.qualityCheck(mainTexPath);
                console.log(`品質スコア: ${quality.data.quality_score}/100`);
            }
        }
    },

    /**
     * バッチ処理の例
     */
    async batchProcessing() {
        const client = new LatexApiClient();
        
        // 複数のプロジェクトを一括作成
        const projectConfigs = [
            { semester: '2024-fall', course: 'physics', name: 'lab1', template: 'report-experiment.tex' },
            { semester: '2024-fall', course: 'physics', name: 'lab2', template: 'report-experiment.tex' },
            { semester: '2024-fall', course: 'math', name: 'homework1', template: 'report-basic.tex' }
        ];

        for (const config of projectConfigs) {
            try {
                console.log(`Creating project: ${config.name}`);
                const project = await client.createProject(
                    config.semester, 
                    config.course, 
                    config.name, 
                    config.template
                );
                
                if (project.success) {
                    const mainTexPath = project.data.project_path + '/main.tex';
                    
                    // 自動コンパイル
                    const compile = await client.compileDocument(mainTexPath);
                    console.log(`  Compile: ${compile.success ? '✅' : '❌'}`);
                    
                    // 品質チェック
                    const quality = await client.qualityCheck(mainTexPath);
                    console.log(`  Quality: ${quality.data.quality_score}/100`);
                }
            } catch (error) {
                console.log(`  Error: ${error.message}`);
            }
        }
    },

    /**
     * ファイル監視とオートコンパイルの例（シミュレート）
     */
    async autoCompileSimulation() {
        const client = new LatexApiClient();
        
        // プロジェクト作成
        const project = await client.createProject(
            '2024-fall', 
            'programming', 
            'auto-compile-demo',
            'report-programming.tex'
        );
        
        if (!project.success) return;
        
        const mainTexPath = project.data.project_path + '/main.tex';
        
        console.log('🔄 自動コンパイルシミュレーション開始...');
        
        // 定期的にファイルの状態をチェックしてコンパイル
        for (let i = 0; i < 3; i++) {
            console.log(`\n🔄 コンパイル実行 ${i + 1}/3`);
            
            const compile = await client.compileDocument(mainTexPath);
            if (compile.success) {
                console.log('✅ コンパイル成功');
                if (compile.data.pdf_info) {
                    console.log(`📄 PDF: ${compile.data.pdf_info.size_mb}MB`);
                }
            } else {
                console.log('❌ コンパイル失敗');
            }
            
            // 2秒待機
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
        
        console.log('🎉 自動コンパイルシミュレーション完了');
    }
};

// メイン実行部分
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args[0] === 'demo') {
        interactiveDemo();
    } else if (args[0] === 'basic') {
        examples.basicUsage();
    } else if (args[0] === 'batch') {
        examples.batchProcessing();
    } else if (args[0] === 'auto') {
        examples.autoCompileSimulation();
    } else {
        main();
    }
}

module.exports = { LatexApiClient, examples };