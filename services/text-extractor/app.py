from flask import Flask, request, jsonify
from readability import Document
import requests
from bs4 import BeautifulSoup

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"})

@app.route('/extract', methods=['POST'])
def extract():
    """
    Extract clean text from a URL or HTML content.
    
    Request JSON:
        - url: URL to fetch and extract (optional if html provided)
        - html: Raw HTML content to extract (optional if url provided)
    
    Response JSON:
        - title: Extracted article title
        - content: Clean text content
        - html: Cleaned HTML summary
    """
    data = request.get_json() or {}
    url = data.get('url')
    html = data.get('html')
    
    try:
        if url and not html:
            resp = requests.get(url, timeout=30, headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            })
            resp.raise_for_status()
            html = resp.text
        
        if not html:
            return jsonify({"error": "No URL or HTML provided"}), 400
        
        doc = Document(html)
        soup = BeautifulSoup(doc.summary(), 'html.parser')
        
        return jsonify({
            "title": doc.title(),
            "content": soup.get_text(separator='\n', strip=True),
            "html": doc.summary()
        })
    except requests.RequestException as e:
        return jsonify({"error": f"Failed to fetch URL: {str(e)}"}), 502
    except Exception as e:
        return jsonify({"error": f"Extraction failed: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
