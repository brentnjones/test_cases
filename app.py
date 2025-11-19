"""
OpenShift Virtualization Test Plan Tracker - Backend API
Flask application with PostgreSQL database
"""

from flask import Flask, jsonify, request, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from datetime import datetime
import os

app = Flask(__name__, static_folder='static')
CORS(app)

# Database configuration
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'postgres')
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'testcases')

app.config['SQLALCHEMY_DATABASE_URI'] = f'postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)


# Database Models
class TestCase(db.Model):
    """Test case definition"""
    __tablename__ = 'test_cases'
    
    id = db.Column(db.String(10), primary_key=True)
    phase = db.Column(db.String(100), nullable=False)
    name = db.Column(db.String(200), nullable=False)
    objective = db.Column(db.Text, nullable=False)
    priority = db.Column(db.String(20), nullable=False)
    
    def to_dict(self):
        return {
            'id': self.id,
            'phase': self.phase,
            'name': self.name,
            'objective': self.objective,
            'priority': self.priority
        }


class TestResult(db.Model):
    """Test execution results"""
    __tablename__ = 'test_results'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    test_id = db.Column(db.String(10), db.ForeignKey('test_cases.id'), nullable=False)
    status = db.Column(db.String(20), default='Pending')
    date_tested = db.Column(db.Date, nullable=True)
    tester = db.Column(db.String(100), nullable=True)
    comments = db.Column(db.Text, nullable=True)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    test_case = db.relationship('TestCase', backref='results')
    
    def to_dict(self):
        return {
            'id': self.id,
            'test_id': self.test_id,
            'status': self.status,
            'date_tested': self.date_tested.isoformat() if self.date_tested else None,
            'tester': self.tester,
            'comments': self.comments,
            'updated_at': self.updated_at.isoformat()
        }


# Initialize database with test cases
def init_test_cases():
    """Initialize database with default test cases"""
    test_cases_data = [
        # Phase 1: Installation and Configuration
        {'phase': 'Phase 1: Installation', 'id': '1.1', 'name': 'OpenShift Virtualization Operator Installation', 'objective': 'Validate operator installation and configuration', 'priority': 'High'},
        {'phase': 'Phase 1: Installation', 'id': '1.2', 'name': 'Host Device Assignment', 'objective': 'Test SR-IOV and GPU passthrough capabilities', 'priority': 'Medium'},
        
        # Phase 2: Storage Testing
        {'phase': 'Phase 2: Storage', 'id': '2.1', 'name': 'Storage Backend Integration', 'objective': 'Validate multiple storage backend support', 'priority': 'High'},
        {'phase': 'Phase 2: Storage', 'id': '2.2', 'name': 'Storage Performance Benchmarking', 'objective': 'Compare storage performance with VMware baseline', 'priority': 'High'},
        {'phase': 'Phase 2: Storage', 'id': '2.3', 'name': 'Storage Live Migration', 'objective': 'Test live storage migration capabilities', 'priority': 'Medium'},
        
        # Phase 3: Network Testing
        {'phase': 'Phase 3: Networking', 'id': '3.1', 'name': 'Standard Pod Network', 'objective': 'Test basic VM networking using pod network', 'priority': 'High'},
        {'phase': 'Phase 3: Networking', 'id': '3.2', 'name': 'Multus and SR-IOV Networking', 'objective': 'Test advanced networking with multiple interfaces', 'priority': 'High'},
        {'phase': 'Phase 3: Networking', 'id': '3.3', 'name': 'Load Balancer and Service Integration', 'objective': 'Test VM exposure via Kubernetes Services', 'priority': 'Medium'},
        {'phase': 'Phase 3: Networking', 'id': '3.4', 'name': 'Network Policies and Microsegmentation', 'objective': 'Test network security and isolation', 'priority': 'High'},
        
        # Phase 4: Backup and Restore
        {'phase': 'Phase 4: Backup/Restore', 'id': '4.1', 'name': 'VM Snapshot and Restore', 'objective': 'Test built-in snapshot capabilities', 'priority': 'High'},
        {'phase': 'Phase 4: Backup/Restore', 'id': '4.2', 'name': 'OADP Backup and Recovery', 'objective': 'Test OpenShift API for Data Protection', 'priority': 'High'},
        {'phase': 'Phase 4: Backup/Restore', 'id': '4.3', 'name': 'Third-Party Backup Solutions', 'objective': 'Test integration with enterprise backup tools', 'priority': 'Medium'},
        
        # Phase 5: Identity and Access Management
        {'phase': 'Phase 5: IAM', 'id': '5.1', 'name': 'LDAP/Active Directory Integration', 'objective': 'Test enterprise directory integration', 'priority': 'High'},
        {'phase': 'Phase 5: IAM', 'id': '5.2', 'name': 'Multi-Tenancy and Project Isolation', 'objective': 'Test tenant isolation capabilities', 'priority': 'High'},
        {'phase': 'Phase 5: IAM', 'id': '5.3', 'name': 'Service Accounts and API Access', 'objective': 'Test programmatic VM management', 'priority': 'Medium'},
        
        # Phase 6: High Availability and DR
        {'phase': 'Phase 6: HA/DR', 'id': '6.1', 'name': 'Live Migration', 'objective': 'Test VM live migration capabilities', 'priority': 'High'},
        {'phase': 'Phase 6: HA/DR', 'id': '6.2', 'name': 'Node Failure and VM Restart', 'objective': 'Test HA behavior during node failure', 'priority': 'High'},
        {'phase': 'Phase 6: HA/DR', 'id': '6.3', 'name': 'Cluster Disaster Recovery', 'objective': 'Test disaster recovery to secondary cluster', 'priority': 'Medium'},
        
        # Phase 7: VM Lifecycle Management
        {'phase': 'Phase 7: VM Lifecycle', 'id': '7.1', 'name': 'VM Templates and Cloning', 'objective': 'Test VM template creation and cloning', 'priority': 'High'},
        {'phase': 'Phase 7: VM Lifecycle', 'id': '7.2', 'name': 'Hot-Plug Resources', 'objective': 'Test dynamic resource modification', 'priority': 'Medium'},
        {'phase': 'Phase 7: VM Lifecycle', 'id': '7.3', 'name': 'Guest Agent and Integration', 'objective': 'Test QEMU guest agent functionality', 'priority': 'Medium'},
        
        # Phase 8: Windows VM Support
        {'phase': 'Phase 8: Windows Support', 'id': '8.1', 'name': 'Windows VM Deployment', 'objective': 'Test Windows Server and desktop support', 'priority': 'High'},
        {'phase': 'Phase 8: Windows Support', 'id': '8.2', 'name': 'Windows-Specific Features', 'objective': 'Test Windows-centric capabilities', 'priority': 'Medium'},
        
        # Phase 9: Performance and Scalability
        {'phase': 'Phase 9: Performance', 'id': '9.1', 'name': 'Density Testing', 'objective': 'Determine maximum VM density per node', 'priority': 'High'},
        {'phase': 'Phase 9: Performance', 'id': '9.2', 'name': 'Application Performance Testing', 'objective': 'Test real-world application performance', 'priority': 'High'},
        {'phase': 'Phase 9: Performance', 'id': '9.3', 'name': 'Stress Testing', 'objective': 'Test platform under extreme conditions', 'priority': 'Medium'},
        
        # Phase 10: Monitoring and Observability
        {'phase': 'Phase 10: Monitoring', 'id': '10.1', 'name': 'Built-in Monitoring Integration', 'objective': 'Test OpenShift monitoring for VMs', 'priority': 'High'},
        {'phase': 'Phase 10: Monitoring', 'id': '10.2', 'name': 'Third-Party Monitoring Integration', 'objective': 'Test integration with enterprise monitoring tools', 'priority': 'Medium'},
        
        # Phase 11: Migration from VMware
        {'phase': 'Phase 11: Migration', 'id': '11.1', 'name': 'MTV (Migration Toolkit for Virtualization)', 'objective': 'Test automated VM migration from VMware', 'priority': 'High'},
        {'phase': 'Phase 11: Migration', 'id': '11.2', 'name': 'Manual Migration Process', 'objective': 'Document manual migration procedure', 'priority': 'Medium'},
        
        # Phase 12: Day 2 Operations
        {'phase': 'Phase 12: Day 2 Ops', 'id': '12.1', 'name': 'Patching and Updates', 'objective': 'Test update procedures for VMs and platform', 'priority': 'High'},
        {'phase': 'Phase 12: Day 2 Ops', 'id': '12.2', 'name': 'Troubleshooting and Support', 'objective': 'Evaluate troubleshooting capabilities', 'priority': 'Medium'},
        
        # Phase 13: Security and Compliance
        {'phase': 'Phase 13: Security', 'id': '13.1', 'name': 'Security Hardening', 'objective': 'Validate security features', 'priority': 'High'},
        {'phase': 'Phase 13: Security', 'id': '13.2', 'name': 'Compliance Validation', 'objective': 'Test compliance framework support', 'priority': 'High'},
        
        # Phase 14: Cost Analysis
        {'phase': 'Phase 14: Cost Analysis', 'id': '14.1', 'name': 'TCO Comparison', 'objective': 'Calculate total cost of ownership', 'priority': 'High'}
    ]
    
    for tc_data in test_cases_data:
        if not TestCase.query.get(tc_data['id']):
            tc = TestCase(**tc_data)
            db.session.add(tc)
            # Create default result entry
            result = TestResult(test_id=tc_data['id'], status='Pending')
            db.session.add(result)
    
    db.session.commit()


# API Routes
@app.route('/')
def index():
    """Serve the main HTML page"""
    return send_from_directory('static', 'index.html')


@app.route('/api/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'database': 'connected'}), 200


@app.route('/api/test-cases', methods=['GET'])
def get_test_cases():
    """Get all test cases with their current results"""
    # Get all test cases and sort them properly by numeric ID
    test_cases = TestCase.query.all()
    
    # Custom sort function to handle numeric sorting of IDs like "1.1", "2.1", "10.1"
    def sort_key(tc):
        try:
            parts = tc.id.split('.')
            return (int(parts[0]), int(parts[1]) if len(parts) > 1 else 0)
        except (ValueError, IndexError):
            return (999, 999)  # Put malformed IDs at the end
    
    test_cases.sort(key=sort_key)
    results = {}
    
    # Get the latest result for each test case
    for tc in test_cases:
        latest_result = TestResult.query.filter_by(test_id=tc.id).order_by(TestResult.updated_at.desc()).first()
        results[tc.id] = latest_result.to_dict() if latest_result else None
    
    return jsonify({
        'test_cases': [tc.to_dict() for tc in test_cases],
        'results': results
    }), 200


@app.route('/api/test-results', methods=['GET'])
def get_all_results():
    """Get all test results"""
    results = TestResult.query.order_by(TestResult.test_id).all()
    return jsonify([r.to_dict() for r in results]), 200


@app.route('/api/test-results/<test_id>', methods=['GET'])
def get_test_result(test_id):
    """Get result for a specific test case"""
    result = TestResult.query.filter_by(test_id=test_id).order_by(TestResult.updated_at.desc()).first()
    if result:
        return jsonify(result.to_dict()), 200
    return jsonify({'error': 'Result not found'}), 404


@app.route('/api/test-results/<test_id>', methods=['PUT'])
def update_test_result(test_id):
    """Update test result"""
    data = request.json
    
    # Get the latest result or create new one
    result = TestResult.query.filter_by(test_id=test_id).order_by(TestResult.updated_at.desc()).first()
    
    if not result:
        result = TestResult(test_id=test_id)
        db.session.add(result)
    
    # Update fields
    if 'status' in data:
        result.status = data['status']
    if 'date_tested' in data and data['date_tested']:
        result.date_tested = datetime.fromisoformat(data['date_tested'].split('T')[0])
    if 'tester' in data:
        result.tester = data['tester']
    if 'comments' in data:
        result.comments = data['comments']
    
    db.session.commit()
    return jsonify(result.to_dict()), 200


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get statistics about test execution"""
    total = TestCase.query.count()
    
    # Get latest results for each test
    latest_results = db.session.query(
        TestResult.test_id,
        TestResult.status
    ).distinct(TestResult.test_id).order_by(
        TestResult.test_id,
        TestResult.updated_at.desc()
    ).all()
    
    stats = {
        'Pass': 0,
        'Fail': 0,
        'Pending': 0
    }
    
    for _, status in latest_results:
        stats[status] = stats.get(status, 0) + 1
    
    completion_pct = round(((stats['Pass'] + stats['Fail']) / total) * 100) if total > 0 else 0
    
    return jsonify({
        'total': total,
        'passed': stats['Pass'],
        'failed': stats['Fail'],
        'pending': stats['Pending'],
        'completion_pct': completion_pct
    }), 200


@app.route('/api/export', methods=['GET'])
def export_data():
    """Export all data for Excel generation"""
    # Get all test cases and sort them properly by numeric ID
    test_cases = TestCase.query.all()
    
    # Custom sort function to handle numeric sorting of IDs like "1.1", "2.1", "10.1"
    def sort_key(tc):
        try:
            parts = tc.id.split('.')
            return (int(parts[0]), int(parts[1]) if len(parts) > 1 else 0)
        except (ValueError, IndexError):
            return (999, 999)  # Put malformed IDs at the end
    
    test_cases.sort(key=sort_key)
    data = []
    
    for tc in test_cases:
        result = TestResult.query.filter_by(test_id=tc.id).order_by(TestResult.updated_at.desc()).first()
        data.append({
            'test_case': tc.to_dict(),
            'result': result.to_dict() if result else None
        })
    
    return jsonify(data), 200


# Database initialization
@app.before_request
def initialize_database():
    """Initialize database on first request"""
    if not hasattr(app, 'db_initialized'):
        db.create_all()
        init_test_cases()
        app.db_initialized = True


if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
