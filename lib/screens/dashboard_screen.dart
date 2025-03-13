import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  User? user;
  Map<String, dynamic>? healthData;
  int _selectedIndex = 0; // Default: Health Records Screen

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    if (user != null) {
      fetchHealthData();
    }
  }

  void fetchHealthData() {
    _dbRef.child("health_records").child(user!.uid).onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          healthData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });
  }

  Future<Map<String, dynamic>?> fetchPatientInfo() async {
    final snapshot = await _dbRef.child("patients").child(user!.uid).get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  int calculateAge(String dob) {
    DateTime birthDate = DateFormat("yyyy-MM-dd").parse(dob);
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Widget buildHealthData() {
    return healthData == null
        ? Center(child: CircularProgressIndicator())
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Health Data", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                SizedBox(height: 10),
                buildDataRow("Heart Rate", "${healthData!['heart_rate']} BPM"),
                buildDataRow("SpO2", "${healthData!['SpO2']}%"),
                buildDataRow("Temperature", "${healthData!['temperature']}°C"),
              ],
            ),
          );
  }

  Widget buildPatientInfo() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: fetchPatientInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(child: Text("No patient info found"));
        }

        var patientInfo = snapshot.data!;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Patient Information", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
              SizedBox(height: 10),
              buildDataRow("Name", patientInfo['name']),
              buildDataRow("Age", "${calculateAge(patientInfo['dob'])} years"),
              buildDataRow("Weight", "${patientInfo['weight']} kg"),
              buildDataRow("Height", "${patientInfo['height']} cm"),
              buildDataRow("Blood Type", patientInfo['blood_type']),
              buildDataRow("Sex", patientInfo['sex']),
            ],
          ),
        );
      },
    );
  }

  Widget buildDataRow(String title, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.teal.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87)),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.teal.shade700)),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        title: Text("Health Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: _selectedIndex == 0 ? buildHealthData() : buildPatientInfo(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Health Records"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Patient Info"),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
