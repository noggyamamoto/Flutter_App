import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_app/features/songs/data/datasources/songs_remote_datasource.dart';
import 'package:flutter_app/features/songs/data/models/songs_model.dart';

class SongsRemoteDatasourceImpl implements SongsRemoteDataSource{
  final FirebaseFirestore firestore;

  SongsRemoteDatasourceImpl(this.firestore);

  @override
  Future<List<SongsModel>> getSongs() async {
    final snapshot = await firestore.collection('partituras').get();

    return snapshot.docs.map((doc) {
      return SongsModel.fromMap({
        'id': doc.id,
        ...doc.data(),
      });
    }).toList();
  }
}