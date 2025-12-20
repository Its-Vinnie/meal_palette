import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_palette/model/recipe_model.dart';

class FirestoreService {
  //* Reference for firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  //* Method to save recipes from API to firestore
  Future<void> saveRecipe(List<Recipe> recipeData) async {
    //* getting reference of the collection in firestore
    try {
      CollectionReference recipes = _db.collection('recipes');

      //* we are using recipe id as the name of the document of each recipe
      String recipeId = recipeData[0].toString();

      //* saving the recipes in the recipes collection
      await recipes.doc(recipeId).set(recipeData);

      print("recipes saved successfully");
    } on Exception catch (e) {
      print("Error saving recipe $e");
      rethrow;
    }
  }

  // * get a recipe with recipe id
  Future<Map<String, dynamic>?> getRecipe(String recipeId) async {
    try {
      DocumentSnapshot doc = await _db
          .collection('recipes')
          .doc(recipeId)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        print("Recipe not found");
        return null;
      }
    } on Exception catch (e) {
      print("error retriving recipe $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>?> getAllRecipes() async {
    try {
      QuerySnapshot querySnapshot = await _db.collection('recipes').get();

      List<Map<String, dynamic>> recipes = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        recipes.add(data);
      }
      return recipes;
    } catch (e) {
      print("Error getting recipes $e");
      return [];
    }
  }


  Future<bool> recipeExist(String recipeId) async {
    try {
      DocumentSnapshot doc = await _db
          .collection('recipes')
          .doc(recipeId)
          .get();
      return doc.exists;
    } catch (e) {
      print("Recipes doesn't exist $e");
      return false;
    }
  }

  // Update a recipe
Future<void> updateRecipe(String recipeId, Map<String, dynamic> updates) async {
  try {
    await _db.collection('recipes').doc(recipeId).update(updates);
    print('Recipe updated successfully!');
  } catch (e) {
    print('Error updating recipe: $e');
    rethrow;
  }
}

// Delete a recipe
Future<void> deleteRecipe(String recipeId) async {
  try {
    await _db.collection('recipes').doc(recipeId).delete();
    print('Recipe deleted successfully!');
  } catch (e) {
    print('Error deleting recipe: $e');
    rethrow;
  }
}
}
